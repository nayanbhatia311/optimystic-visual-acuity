import Foundation

enum PeerSessionMessageType: String, Codable {
    case requestDisplayCapabilities
    case displayCapabilities
    case startDisplay
    case updateDisplay
    case endDisplay
    /// Sent by an iPhone peer-display to its Mac controller.
    /// The iPhone receives the Watch button press via WatchConnectivity and
    /// forwards it here so the Mac can score without needing its own WCSession.
    case relayWatchCommand
    /// Controller → Display: tell the display to render the "cover your X eye"
    /// instruction while the examiner is getting the patient ready. Carries
    /// `instructedEye` to indicate which eye is being tested.
    case showEyeHelper
}

struct DisplayCapabilityState: Codable, Equatable {
    let deviceName: String
    let minimumScreenDimensionMillimeters: Double
    let maxOptotypeSizeMillimeters: Double
    let maxViewingDistanceMeters: Double
    let limitingLineLabel: String
}

struct PeerDisplayState: Codable, Equatable {
    let patientID: String
    let eyeSelection: EyeSelection
    let viewingDistanceMeters: Double
    let fieldTestMode: FieldTestMode
    let optotypeFamily: OptotypeFamily
    let symbol: String
    let orientation: OptotypeOrientation
    let lineLabel: String
    let physicalOptotypeSizeMillimeters: Double
    let itemNumber: Int
    let itemsPerLine: Int
    let lastEventDescription: String
    let controllerMode: ExaminerControlMode
    let showExaminerOverlay: Bool
}

struct PeerSessionMessage: Codable, Equatable {
    let type: PeerSessionMessageType
    let displayState: PeerDisplayState?
    let resultText: String?
    let displayCapabilities: DisplayCapabilityState?
    /// Raw value of `WatchCommandType` — only set for `.relayWatchCommand` messages.
    let relayedWatchCommandType: String?
    /// Only set for `.showEyeHelper` — which eye the patient is being asked to test.
    let instructedEye: EyeSelection?

    init(
        type: PeerSessionMessageType,
        displayState: PeerDisplayState? = nil,
        resultText: String? = nil,
        displayCapabilities: DisplayCapabilityState? = nil,
        relayedWatchCommandType: String? = nil,
        instructedEye: EyeSelection? = nil
    ) {
        self.type = type
        self.displayState = displayState
        self.resultText = resultText
        self.displayCapabilities = displayCapabilities
        self.relayedWatchCommandType = relayedWatchCommandType
        self.instructedEye = instructedEye
    }
}
