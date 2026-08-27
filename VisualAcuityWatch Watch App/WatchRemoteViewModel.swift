import Foundation
import Combine

@MainActor
final class WatchRemoteViewModel: ObservableObject {
    enum TestState {
        case idle
        case active(patientID: String, eye: String, optotype: String)
        case finished(result: String)
    }

    @Published private(set) var testState: TestState = .idle
    @Published private(set) var isTestActive = false
    /// MPC display devices discovered on the paired iPhone, awaiting selection.
    @Published private(set) var availablePeers: [String] = []
    /// The MPC device the iPhone is currently connected to (if any).
    @Published private(set) var connectedDeviceName: String?
    /// Latest MPC connection status text pushed from the iPhone.
    @Published private(set) var peerStatusText: String = ""
    /// Simulator-only visual feedback used while recording deterministic demos.
    @Published private(set) var highlightedSimulatorCommand: WatchCommandType?

    let connectivityManager: WatchConnectivityManager
    private var didStartSimulatorScript = false
    private var simulatorScriptTask: Task<Void, Never>?

    init(connectivityManager: WatchConnectivityManager? = nil) {
        self.connectivityManager = connectivityManager ?? WatchConnectivityManager()

        self.connectivityManager.onCommand = { [weak self] command in
            Task { @MainActor in
                self?.handleIncomingCommand(command)
            }
        }
    }

    // MARK: – Actions

    func send(_ commandType: WatchCommandType) {
        connectivityManager.send(commandType)

        if commandType == .endTest {
            testState = .finished(result: "Ended")
            isTestActive = false
        }
    }

    /// Tell the paired iPhone to connect to the named MPC peer.
    func selectPeer(_ name: String) {
        connectivityManager.send(.selectPeer, payload: ["name": name])
    }

    // MARK: – Display helpers

    var statusLine: String {
        switch testState {
        case .idle:
            if let device = connectedDeviceName {
                return "Controlling \(device)"
            }
            if !peerStatusText.isEmpty {
                return peerStatusText
            }
            return "Waiting for device"
        case .active(let patientID, let eye, let optotype):
            return "\(patientID) • \(eye)\n\(optotype)"
        case .finished(let result):
            return result
        }
    }

    var idlePrompt: String {
        if let device = connectedDeviceName {
            return "Start a test on \(device) to enable controls."
        }
        return "Connect a display device from the iPhone app, then start a test. Mac control uses the iPhone or iPad as the watch relay."
    }

    // MARK: – Incoming messages from iPhone

    private func handleIncomingCommand(_ command: WatchCommand) {
        switch command.type {
        case .startTest:
            let patient = command.payload["patientID"] ?? "Anonymous"
            let eye = command.payload["eye"] ?? "?"
            let optotype = command.payload["optotype"] ?? "Optotype"
            testState = .active(patientID: patient, eye: eye, optotype: optotype)
            isTestActive = true
            startSimulatorScriptIfNeeded()

        case .endTest:
            let result = command.payload["result"] ?? "Finished"
            testState = .finished(result: result)
            isTestActive = false

        case .availablePeers:
            let raw = command.payload["peers"] ?? ""
            availablePeers = raw.isEmpty ? [] : raw.components(separatedBy: ",")

        case .peerConnected:
            connectedDeviceName = command.payload["name"]
            availablePeers = []

        case .peerStatus:
            // Full snapshot from iPhone — always apply so Watch has current state.
            peerStatusText = command.payload["statusText"] ?? ""
            let device = command.payload["device"] ?? ""
            let rawPeers = command.payload["peers"] ?? ""
            connectedDeviceName = device.isEmpty ? nil : device
            if connectedDeviceName != nil {
                availablePeers = [] // connected — clear any leftover picker
            } else {
                availablePeers = rawPeers.isEmpty ? [] : rawPeers.components(separatedBy: ",")
            }

        case .responseCorrect, .responseWrong, .repeatItem, .nextItem, .selectPeer:
            break // sent Watch → iPhone, not received by Watch
        }
    }

    private func startSimulatorScriptIfNeeded() {
        guard !didStartSimulatorScript else { return }

        let environment = ProcessInfo.processInfo.environment
        let steps = environment["VA_WATCH_RESPONSE_SCRIPT"]?
            .split(separator: ",")
            .compactMap { rawValue -> WatchCommandType? in
                switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "correct": return .responseCorrect
                case "wrong": return .responseWrong
                case "repeat": return .repeatItem
                case "next": return .nextItem
                case "end": return .endTest
                default: return nil
                }
            } ?? []

        guard !steps.isEmpty else { return }
        didStartSimulatorScript = true

        let initialDelay = max(0, Double(environment["VA_WATCH_INITIAL_RESPONSE_DELAY"] ?? "") ?? 0)
        let interval = max(0.8, Double(environment["VA_WATCH_STEP_INTERVAL"] ?? "") ?? 2.0)

        simulatorScriptTask?.cancel()
        simulatorScriptTask = Task { @MainActor [weak self] in
            if initialDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            }

            for step in steps {
                guard let self, !Task.isCancelled else { return }
                highlightedSimulatorCommand = step
                try? await Task.sleep(nanoseconds: 450_000_000)
                send(step)
                highlightedSimulatorCommand = nil

                if step == .endTest { return }
                try? await Task.sleep(nanoseconds: UInt64((interval - 0.45) * 1_000_000_000))
            }
        }
    }
}
