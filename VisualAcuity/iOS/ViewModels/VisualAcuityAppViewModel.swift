import Foundation
import Combine
import CoreGraphics

@MainActor
final class VisualAcuityAppViewModel: ObservableObject {
    enum Screen {
        case roleSelect
        case setup
        case eyeHelper
        case test
        case results
    }

    enum DeviceRole: String, Codable {
        /// One device runs the whole test.
        case standalone
        /// This device scores responses and sends optotypes to a paired display.
        case controller
        /// This device only renders optotypes sent by a paired controller.
        case display
    }

    enum RuntimeMode {
        case standalone
        case peerController
        case peerDisplay
    }

    private static let minimumViewingDistanceMeters = 0.25
    private static let maxOptotypeFillFraction = 0.82
    private static let roleStorageKey = "VisualAcuity.deviceRole.v2"

    // MARK: – Setup inputs
    @Published var patientID = ""
    @Published var selectedEye: EyeSelection = .both
    @Published var distanceMetersText = "3.00"
    @Published var selectedOptotypeFamily: OptotypeFamily = .tumblingE
    @Published var useAppleWatchForScoring = false

    // MARK: – Role & flow
    @Published private(set) var deviceRole: DeviceRole?
    @Published private(set) var screen: Screen = .roleSelect
    @Published private(set) var runtimeMode: RuntimeMode = .standalone

    /// Which eye the engine is currently testing inside a session. This can
    /// differ from `selectedEye` when `.both` is selected and the right eye
    /// runs first, then the left eye.
    @Published private(set) var currentTestingEye: EyeSelection = .right

    @Published private(set) var rightEyeResult: TestResult?
    @Published private(set) var leftEyeResult: TestResult?

    @Published private(set) var remoteDisplayState: PeerDisplayState?
    @Published private(set) var remoteDisplayCapabilities: DisplayCapabilityState?
    @Published private(set) var remoteResultText: String?
    @Published private(set) var currentDisplayMetrics = DisplayMetrics.current()

    // Legacy fields kept so the rest of the codebase (engine, peer payload,
    // watch messages) keeps working without a massive refactor. They are
    // derived from `deviceRole` and `useAppleWatchForScoring`.
    var selectedFieldTestMode: FieldTestMode { .standardChart }
    var showExaminerOverlay: Bool { false }

    let engine: VisualAcuityTestEngine
    let connectivityManager: WatchConnectivityManager
    let peerConnectivityManager: PeerConnectivityManager

    private var didSendEndTestMessage = false
    private var didRunLaunchConfiguration = false
    private var didAutoStartLaunchSession = false
    private var scriptedResponseTask: Task<Void, Never>?
    private var capabilityRequestTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        engine: VisualAcuityTestEngine? = nil,
        connectivityManager: WatchConnectivityManager? = nil,
        peerConnectivityManager: PeerConnectivityManager? = nil
    ) {
        self.engine = engine ?? VisualAcuityTestEngine()
        self.connectivityManager = connectivityManager ?? WatchConnectivityManager()
        self.peerConnectivityManager = peerConnectivityManager ?? PeerConnectivityManager()

        self.connectivityManager.onCommand = { [weak self] command in
            Task { @MainActor in
                self?.handleWatchCommand(command)
            }
        }

        self.peerConnectivityManager.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handlePeerMessage(message)
            }
        }

        // Restore persisted role so returning users skip role picker.
        if let raw = UserDefaults.standard.string(forKey: Self.roleStorageKey),
           let role = DeviceRole(rawValue: raw) {
            self.deviceRole = role
            self.screen = (role == .display) ? .test : .setup
            self.runtimeMode = (role == .display) ? .peerDisplay : .standalone
        }

        bindDistanceInput()
        bindPeerConnectionState()
        refreshPeerModeConfiguration()
    }

    // MARK: – Derived values

    var result: TestResult? {
        engine.result
    }

    var currentSession: ActiveTestSession? {
        engine.session
    }

    /// Mapping from role → legacy display/controller modes used by the engine.
    private var selectedDisplayMode: PatientDisplayMode {
        switch deviceRole {
        case .display:    return .currentDevice
        case .controller: return .peerDevice
        case .standalone, .none: return .currentDevice
        }
    }

    private var selectedControllerMode: ExaminerControlMode {
        if deviceRole == .display {
            return .peerDevice
        }
        return useAppleWatchForScoring ? .appleWatch : .localDevice
    }

    private var numericViewingDistanceMeters: Double? {
        let normalized = distanceMetersText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    var parsedViewingDistanceMeters: Double {
        let fallback = TestConfiguration.defaultStandardDistanceMeters
        guard let value = numericViewingDistanceMeters else { return fallback }

        let boundedMinimum = max(value, Self.minimumViewingDistanceMeters)

        if let maximumSupportedViewingDistanceMeters {
            return min(boundedMinimum, maximumSupportedViewingDistanceMeters)
        }

        return boundedMinimum
    }

    var maximumSupportedViewingDistanceMeters: Double? {
        activeDisplayCapabilities?.maxViewingDistanceMeters
    }

    var viewingDistanceValidationMessage: String? {
        guard peerModeRole != .display else { return nil }

        let trimmed = distanceMetersText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter distance" }
        guard let value = numericViewingDistanceMeters else { return "Use numbers" }

        if value < Self.minimumViewingDistanceMeters {
            return "Min \(String(format: "%.2f", Self.minimumViewingDistanceMeters)) m"
        }

        if selectedDisplayMode == .peerDevice && remoteDisplayCapabilities == nil {
            return "Waiting for display size"
        }

        if let maximumSupportedViewingDistanceMeters, value > maximumSupportedViewingDistanceMeters {
            return "Max \(String(format: "%.2f", maximumSupportedViewingDistanceMeters)) m"
        }

        return nil
    }

    var availableOptotypeFamilies: [OptotypeFamily] {
        OptotypeFamily.allCases.filter(\.isImplementedNow)
    }

    var clinicalDisclaimerText: String {
        PrototypeContent.prototypeDisclaimer
    }

    var deviceStatusSummary: String {
        switch deviceRole {
        case .standalone, .none:
            return useAppleWatchForScoring ? connectivityManager.connectionStatusText : ""
        case .controller:
            return peerConnectivityManager.connectionStatusText
        case .display:
            return peerConnectivityManager.connectionStatusText
        }
    }

    var connectivityActionTitle: String {
        peerConnectivityManager.isConnected ? "Reconnect" : "Scan Again"
    }

    var canStart: Bool {
        switch deviceRole {
        case .display:
            return false  // auto-activates
        case .controller:
            return peerConnectivityManager.isConnected && viewingDistanceValidationMessage == nil
        case .standalone, .none:
            return viewingDistanceValidationMessage == nil
        }
    }

    var startButtonTitle: String { "Start" }

    var peerModeRole: PeerConnectivityManager.Role {
        switch deviceRole {
        case .controller: return .controller
        case .display:    return .display
        case .standalone, .none: return .inactive
        }
    }

    var showsLocalExaminerControls: Bool {
        switch runtimeMode {
        case .peerController:
            return !useAppleWatchForScoring
        case .standalone:
            return !useAppleWatchForScoring
        case .peerDisplay:
            return false
        }
    }

    /// The eye instructed to test in the eye-helper screen.
    var eyeHelperInstructionEye: EyeSelection {
        currentTestingEye
    }

    // MARK: – Role management

    func chooseRole(_ role: DeviceRole) {
        deviceRole = role
        UserDefaults.standard.set(role.rawValue, forKey: Self.roleStorageKey)

        refreshPeerModeConfiguration()

        if role == .display {
            runtimeMode = .peerDisplay
            remoteDisplayState = nil
            remoteResultText = nil
            screen = .test
        } else {
            screen = .setup
            runtimeMode = .standalone
        }
    }

    func clearRole() {
        scriptedResponseTask?.cancel()
        engine.reset()
        deviceRole = nil
        UserDefaults.standard.removeObject(forKey: Self.roleStorageKey)
        screen = .roleSelect
        runtimeMode = .standalone
        remoteDisplayState = nil
        remoteResultText = nil
        rightEyeResult = nil
        leftEyeResult = nil
        refreshPeerModeConfiguration()
    }

    // MARK: – Test lifecycle

    /// Called from setup to move into the eye-helper (prompts patient to cover an eye).
    func beginTestFlow() {
        guard viewingDistanceValidationMessage == nil else { return }

        rightEyeResult = nil
        leftEyeResult = nil

        // Determine which eye to test first.
        currentTestingEye = (selectedEye == .left) ? .left : .right
        screen = .eyeHelper
        sendEyeHelperToDisplayIfNeeded()
    }

    /// When acting as the controller, tell the paired display to render the
    /// "cover your X eye" instruction so the patient sees it too.
    private func sendEyeHelperToDisplayIfNeeded() {
        guard peerModeRole == .controller else { return }

        peerConnectivityManager.send(
            PeerSessionMessage(
                type: .showEyeHelper,
                instructedEye: currentTestingEye
            )
        )
    }

    /// Called from the eye-helper screen after patient has acknowledged.
    func startTestForCurrentEye() {
        startTest(forEye: currentTestingEye)
    }

    private func startTest(forEye eye: EyeSelection) {
        guard numericViewingDistanceMeters != nil else { return }
        if viewingDistanceValidationMessage != nil { return }

        currentTestingEye = eye

        let configuration = TestConfiguration(
            patientID: patientID,
            eyeSelection: eye,
            viewingDistanceMeters: parsedViewingDistanceMeters,
            fieldTestMode: .standardChart,
            displayMode: selectedDisplayMode,
            controllerMode: selectedControllerMode,
            optotypeFamily: selectedOptotypeFamily,
            showExaminerOverlay: false,
            itemsPerLine: TestConfiguration.defaultItemsPerLine,
            passThreshold: TestConfiguration.defaultPassThreshold,
            lines: VisualAcuityLine.paperReferenceLines
        )

        didSendEndTestMessage = false
        remoteResultText = nil
        engine.start(configuration: configuration)
        runtimeMode = peerModeRole == .controller ? .peerController : .standalone
        screen = .test

        if configuration.controllerMode == .appleWatch {
            connectivityManager.send(
                .startTest,
                payload: [
                    "patientID": configuration.displayPatientID,
                    "eye": configuration.eyeSelection.rawValue,
                    "distance": configuration.distanceLabel,
                    "displayMode": configuration.displayMode.rawValue,
                    "controllerMode": configuration.controllerMode.rawValue,
                    "fieldMode": configuration.fieldTestMode.rawValue,
                    "optotype": configuration.optotypeFamily.rawValue,
                ]
            )
        }

        sendPeerDisplayStateIfNeeded(started: true)
    }

    func markCorrect() {
        engine.recordCorrect()
        syncScreenAfterEngineChange()
    }

    func markWrong() {
        engine.recordWrong()
        syncScreenAfterEngineChange()
    }

    func repeatItem() {
        engine.repeatCurrentItem()
        sendPeerDisplayStateIfNeeded(started: false)
    }

    func advanceWithoutScoring() {
        engine.advanceWithoutScoring()
        syncScreenAfterEngineChange()
    }

    func endTest() {
        engine.endTest()
        syncScreenAfterEngineChange()
    }

    /// Called by the tap-to-exit gesture on the controller/test screen.
    /// On display-only devices there is no test to abandon — take the user
    /// back to role selection so they can re-pick how this device is used.
    func exitTestEarly() {
        if deviceRole == .display {
            clearRole()
            return
        }

        scriptedResponseTask?.cancel()
        engine.reset()
        runtimeMode = .standalone
        rightEyeResult = nil
        leftEyeResult = nil
        remoteDisplayState = nil
        remoteResultText = nil
        didSendEndTestMessage = false
        screen = .setup
    }

    func resetToSetup() {
        scriptedResponseTask?.cancel()
        scriptedResponseTask = nil
        engine.reset()
        screen = (deviceRole == .display) ? .test : .setup
        runtimeMode = (deviceRole == .display) ? .peerDisplay : .standalone
        rightEyeResult = nil
        leftEyeResult = nil
        remoteDisplayState = nil
        remoteResultText = nil
        didSendEndTestMessage = false
    }

    func runLaunchConfigurationIfNeeded() {
        guard !didRunLaunchConfiguration else { return }
        didRunLaunchConfiguration = true

        guard let configuration = SimulatorLaunchConfiguration.current() else { return }

        patientID = configuration.patientID
        selectedEye = configuration.eyeSelection
        selectedOptotypeFamily = configuration.optotypeFamily
        useAppleWatchForScoring = configuration.useAppleWatchForScoring

        if let viewingDistanceMeters = configuration.viewingDistanceMeters {
            distanceMetersText = String(format: "%.2f", viewingDistanceMeters)
        }

        switch configuration.role {
        case .local:
            chooseRole(.standalone)
        case .controller:
            chooseRole(.controller)
        case .display:
            chooseRole(.display)
        }

        guard configuration.autoStart else { return }

        switch configuration.role {
        case .display:
            break
        case .local:
            beginTestFlow()
            startTestForCurrentEye()
            startScriptedResponses(
                configuration.responseScript,
                every: configuration.stepIntervalSeconds,
                after: configuration.initialResponseDelaySeconds
            )
        case .controller:
            if peerConnectivityManager.isConnected {
                startAutomatedControllerSession(configuration)
            } else {
                peerConnectivityManager.$isConnected
                    .removeDuplicates()
                    .filter { $0 }
                    .prefix(1)
                    .sink { [weak self] _ in
                        Task { @MainActor in
                            self?.startAutomatedControllerSession(configuration)
                        }
                    }
                    .store(in: &cancellables)
            }
        }
    }

    func optotypeSize(in availableSize: CGSize) -> CGFloat {
        guard let currentSession else {
            return min(availableSize.width, availableSize.height) * 0.3
        }

        return renderedPoints(
            forPhysicalMillimeters: currentSession.currentPhysicalOptotypeSizeMillimeters,
            availableSize: availableSize
        )
    }

    func remoteOptotypeSize(in availableSize: CGSize) -> CGFloat {
        guard let remoteDisplayState else {
            return min(availableSize.width, availableSize.height) * 0.3
        }

        return renderedPoints(
            forPhysicalMillimeters: remoteDisplayState.physicalOptotypeSizeMillimeters,
            availableSize: availableSize
        )
    }

    func updateCurrentDisplayMetrics(_ metrics: DisplayMetrics) {
        guard metrics != currentDisplayMetrics else { return }

        currentDisplayMetrics = metrics
        sendDisplayCapabilitiesIfNeeded()
    }

    // MARK: – Bindings

    private func bindDistanceInput() {
        $distanceMetersText
            .dropFirst()
            .sink { [weak self] text in
                self?.sanitizeDistanceInput(text)
            }
            .store(in: &cancellables)
    }

    private func bindPeerConnectionState() {
        peerConnectivityManager.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                guard let self else { return }

                if !isConnected {
                    self.capabilityRequestTask?.cancel()
                    self.capabilityRequestTask = nil
                    self.remoteDisplayCapabilities = nil
                    return
                }

                switch self.peerModeRole {
                case .display:
                    self.sendDisplayCapabilitiesIfNeeded()
                case .controller:
                    self.requestDisplayCapabilities()
                case .inactive:
                    break
                }
            }
            .store(in: &cancellables)

        peerConnectivityManager.$discoveredPeerNames
            .sink { [weak self] _ in
                self?.sendPeerStatusToWatch()
            }
            .store(in: &cancellables)

        peerConnectivityManager.$connectedPeerDisplayName
            .sink { [weak self] _ in
                self?.sendPeerStatusToWatch()
            }
            .store(in: &cancellables)

        connectivityManager.$isReachable
            .filter { $0 }
            .sink { [weak self] _ in
                self?.sendPeerStatusToWatch()
            }
            .store(in: &cancellables)
    }

    private func refreshPeerModeConfiguration() {
        peerConnectivityManager.configure(role: peerModeRole)

        switch peerModeRole {
        case .controller:
            if peerConnectivityManager.isConnected {
                requestDisplayCapabilities()
            }
        case .display:
            capabilityRequestTask?.cancel()
            capabilityRequestTask = nil
            remoteDisplayCapabilities = nil

            if peerConnectivityManager.isConnected {
                sendDisplayCapabilitiesIfNeeded()
            }
        case .inactive:
            capabilityRequestTask?.cancel()
            capabilityRequestTask = nil
            remoteDisplayCapabilities = nil
        }
    }

    private func handleWatchCommand(_ command: WatchCommand) {
        if runtimeMode == .peerDisplay {
            peerConnectivityManager.send(
                PeerSessionMessage(
                    type: .relayWatchCommand,
                    relayedWatchCommandType: command.type.rawValue
                )
            )
            return
        }

        switch command.type {
        case .startTest:
            break
        case .responseCorrect:
            markCorrect()
        case .responseWrong:
            markWrong()
        case .repeatItem:
            repeatItem()
        case .nextItem:
            advanceWithoutScoring()
        case .endTest:
            endTest()
        case .selectPeer:
            let name = command.payload["name"] ?? ""
            peerConnectivityManager.connect(toPeerNamed: name)
        case .availablePeers, .peerConnected, .peerStatus:
            break
        }
    }

    private func handlePeerMessage(_ message: PeerSessionMessage) {
        switch message.type {
        case .requestDisplayCapabilities:
            sendDisplayCapabilitiesIfNeeded()
        case .displayCapabilities:
            remoteDisplayCapabilities = message.displayCapabilities
            capabilityRequestTask?.cancel()
            capabilityRequestTask = nil
        case .startDisplay, .updateDisplay:
            guard let displayState = message.displayState else { return }
            remoteDisplayState = displayState
            remoteResultText = nil
            runtimeMode = .peerDisplay
            screen = .test
        case .endDisplay:
            remoteDisplayState = nil
            remoteResultText = message.resultText
            runtimeMode = (deviceRole == .display) ? .peerDisplay : .standalone
            screen = (deviceRole == .display) ? .test : .setup
        case .relayWatchCommand:
            guard useAppleWatchForScoring,
                  let rawType = message.relayedWatchCommandType,
                  let commandType = WatchCommandType(rawValue: rawType)
            else { return }
            handleWatchCommand(WatchCommand(type: commandType))
        case .showEyeHelper:
            // Controller is telling us to display the "cover your X eye"
            // instruction to the patient. Only react when we're actually the
            // display device.
            guard deviceRole == .display else { return }
            if let eye = message.instructedEye {
                currentTestingEye = eye
            }
            remoteDisplayState = nil
            runtimeMode = .peerDisplay
            screen = .eyeHelper
        }
    }

    private func syncScreenAfterEngineChange() {
        if let result = engine.result {
            // Record per-eye result and decide whether to chain into the other eye.
            if currentTestingEye == .right {
                rightEyeResult = result
            } else if currentTestingEye == .left {
                leftEyeResult = result
            }

            // If the user originally requested `.both`, chain to the other eye.
            let wantsBothEyes = (selectedEye == .both)
            let justFinishedFirstEye = (currentTestingEye == .right && rightEyeResult != nil && leftEyeResult == nil)
                || (currentTestingEye == .left && leftEyeResult != nil && rightEyeResult == nil)

            if wantsBothEyes && justFinishedFirstEye {
                // Transition into helper for the other eye.
                let nextEye: EyeSelection = (currentTestingEye == .right) ? .left : .right
                currentTestingEye = nextEye
                engine.reset()
                screen = .eyeHelper
                sendEyeHelperToDisplayIfNeeded()
                return
            }

            // Persist this completed test session locally so the user can
            // review and re-export later from History.
            persistCompletedSessionToHistory()

            screen = .results

            if !didSendEndTestMessage {
                didSendEndTestMessage = true
                if useAppleWatchForScoring {
                    connectivityManager.send(.endTest, payload: ["result": result.snellenText])
                }
            }

            if peerModeRole == .controller {
                peerConnectivityManager.send(
                    PeerSessionMessage(
                        type: .endDisplay,
                        displayState: nil,
                        resultText: result.snellenText,
                        displayCapabilities: nil
                    )
                )
            }
        } else if engine.session != nil {
            screen = .test
            sendPeerDisplayStateIfNeeded(started: false)
        } else {
            screen = (deviceRole == .display) ? .test : .setup
        }
    }

    /// Saves the just-finished test (one or both eyes) to on-device history.
    private func persistCompletedSessionToHistory() {
        let right = rightEyeResult
        let left = leftEyeResult
        let fallback = engine.result

        let chosenRight = right
        let chosenLeft = left

        // When no eye-specific results have been recorded (e.g. standalone
        // single-eye run), fall back to the engine's own latest result.
        if chosenRight == nil && chosenLeft == nil, let fallback {
            let session = StoredSession(
                id: UUID(),
                date: fallback.date,
                patientID: fallback.patientID,
                rightEye: fallback.eyeSelection == .left ? nil : fallback,
                leftEye: fallback.eyeSelection == .left ? fallback : nil
            )
            SessionHistoryStore.shared.save(session)
            return
        }

        guard chosenRight != nil || chosenLeft != nil else { return }

        let sessionDate = chosenRight?.date ?? chosenLeft?.date ?? .now
        let patientID = chosenRight?.patientID ?? chosenLeft?.patientID ?? ""

        let session = StoredSession(
            id: UUID(),
            date: sessionDate,
            patientID: patientID,
            rightEye: chosenRight,
            leftEye: chosenLeft
        )
        SessionHistoryStore.shared.save(session)
    }

    private func sendPeerDisplayStateIfNeeded(started: Bool) {
        guard peerModeRole == .controller, let session = engine.session else { return }

        let displayState = PeerDisplayState(
            patientID: session.configuration.displayPatientID,
            eyeSelection: session.configuration.eyeSelection,
            viewingDistanceMeters: session.configuration.viewingDistanceMeters,
            fieldTestMode: session.configuration.fieldTestMode,
            optotypeFamily: session.configuration.optotypeFamily,
            symbol: session.currentOptotypeSymbol,
            orientation: session.currentOrientation,
            lineLabel: session.currentLine.displayLabel,
            physicalOptotypeSizeMillimeters: session.currentPhysicalOptotypeSizeMillimeters,
            itemNumber: session.currentItemNumber,
            itemsPerLine: session.configuration.itemsPerLine,
            lastEventDescription: session.lastEventDescription,
            controllerMode: session.configuration.controllerMode,
            showExaminerOverlay: false
        )

        peerConnectivityManager.send(
            PeerSessionMessage(
                type: started ? .startDisplay : .updateDisplay,
                displayState: displayState,
                resultText: nil,
                displayCapabilities: nil
            )
        )
    }

    private func sendPeerStatusToWatch() {
        let device = peerConnectivityManager.connectedPeerDisplayName ?? ""
        let statusText = peerConnectivityManager.connectionStatusText
        let peers = peerConnectivityManager.discoveredPeerNames.joined(separator: ",")
        connectivityManager.send(
            .peerStatus,
            payload: [
                "statusText": statusText,
                "device": device,
                "peers": peers
            ]
        )
    }

    private func sendDisplayCapabilitiesIfNeeded() {
        guard peerModeRole == .display, let currentDeviceDisplayCapabilities else { return }

        peerConnectivityManager.send(
            PeerSessionMessage(
                type: .displayCapabilities,
                displayState: nil,
                resultText: nil,
                displayCapabilities: currentDeviceDisplayCapabilities
            )
        )
    }

    private func requestDisplayCapabilities() {
        guard peerModeRole == .controller, peerConnectivityManager.isConnected else { return }

        capabilityRequestTask?.cancel()
        capabilityRequestTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for _ in 0..<5 {
                guard self.peerModeRole == .controller, self.peerConnectivityManager.isConnected else { return }
                if self.remoteDisplayCapabilities != nil { return }

                self.peerConnectivityManager.send(
                    PeerSessionMessage(
                        type: .requestDisplayCapabilities,
                        displayState: nil,
                        resultText: nil,
                        displayCapabilities: nil
                    )
                )

                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    func normalizeDistanceInput() {
        let fallback = TestConfiguration.defaultStandardDistanceMeters
        let normalizedValue: Double

        if let numericViewingDistanceMeters {
            let lowerBounded = max(numericViewingDistanceMeters, Self.minimumViewingDistanceMeters)

            if let maximumSupportedViewingDistanceMeters {
                normalizedValue = min(lowerBounded, maximumSupportedViewingDistanceMeters)
            } else {
                normalizedValue = lowerBounded
            }
        } else {
            normalizedValue = fallback
        }

        let formatted = String(format: "%.2f", normalizedValue)
        if distanceMetersText != formatted {
            distanceMetersText = formatted
        }
    }

    func beginEditingDistanceIfNeeded() {
        if distanceMetersText == String(format: "%.2f", TestConfiguration.defaultStandardDistanceMeters) {
            distanceMetersText = ""
        }
    }

    private func sanitizeDistanceInput(_ rawText: String) {
        let normalized = rawText.replacingOccurrences(of: ",", with: ".")
        var sanitized = ""
        var didUseDecimalSeparator = false
        var fractionalDigitCount = 0

        for character in normalized {
            if character.isNumber {
                if didUseDecimalSeparator {
                    guard fractionalDigitCount < 2 else { continue }
                    fractionalDigitCount += 1
                }
                sanitized.append(character)
            } else if character == ".", !didUseDecimalSeparator {
                didUseDecimalSeparator = true
                sanitized.append(sanitized.isEmpty ? "0." : ".")
            }
        }

        if sanitized != rawText {
            distanceMetersText = sanitized
        }
    }

    private var activeDisplayCapabilities: DisplayCapabilityState? {
        if selectedDisplayMode == .peerDevice {
            return remoteDisplayCapabilities
        }

        return currentDeviceDisplayCapabilities
    }

    private var currentDeviceDisplayCapabilities: DisplayCapabilityState? {
        guard let limitingLine = VisualAcuityLine.paperReferenceLines.first else { return nil }

        let metrics = currentDisplayMetrics
        let minimumScreenDimensionMillimeters = metrics.minimumScreenDimensionMillimeters
        guard minimumScreenDimensionMillimeters > 0 else { return nil }

        let maxOptotypeSizeMillimeters = minimumScreenDimensionMillimeters * Self.maxOptotypeFillFraction
        let maxViewingDistanceMeters = OptotypeSizing.viewingDistanceMeters(
            forPhysicalSizeMillimeters: maxOptotypeSizeMillimeters,
            line: limitingLine
        )

        return DisplayCapabilityState(
            deviceName: LocalDeviceIdentity.displayName,
            minimumScreenDimensionMillimeters: minimumScreenDimensionMillimeters,
            maxOptotypeSizeMillimeters: maxOptotypeSizeMillimeters,
            maxViewingDistanceMeters: maxViewingDistanceMeters,
            limitingLineLabel: limitingLine.displayLabel
        )
    }

    private func renderedPoints(forPhysicalMillimeters millimeters: Double, availableSize _: CGSize) -> CGFloat {
        let rendered = CGFloat(millimeters) * currentDisplayMetrics.pointsPerMillimeter
        return max(1, rendered)
    }

    private func startAutomatedControllerSession(_ configuration: SimulatorLaunchConfiguration) {
        guard !didAutoStartLaunchSession else { return }

        // A peer can report as connected just before its display-capability
        // payload arrives. Wait for the same readiness gate as the real Start
        // button so deterministic Simulator demos do not stall on setup.
        guard canStart else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000)
                self?.startAutomatedControllerSession(configuration)
            }
            return
        }

        didAutoStartLaunchSession = true
        beginTestFlow()
        startTestForCurrentEye()
        startScriptedResponses(
            configuration.responseScript,
            every: configuration.stepIntervalSeconds,
            after: configuration.initialResponseDelaySeconds
        )
    }

    private func startScriptedResponses(
        _ steps: [SimulatorLaunchConfiguration.ResponseStep],
        every interval: Double,
        after initialDelay: Double = 0
    ) {
        guard !steps.isEmpty else { return }

        scriptedResponseTask?.cancel()
        scriptedResponseTask = Task { @MainActor in
            if initialDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            }

            for step in steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                switch step {
                case .correct:
                    markCorrect()
                case .wrong:
                    markWrong()
                case .repeatItem:
                    repeatItem()
                case .next:
                    advanceWithoutScoring()
                case .end:
                    endTest()
                }

                if engine.session == nil {
                    return
                }
            }
        }
    }
}
