import Foundation

struct SimulatorLaunchConfiguration {
    enum Role: String {
        case local
        case controller
        case display
    }

    enum ResponseStep: String {
        case correct
        case wrong
        case repeatItem = "repeat"
        case next
        case end
    }

    let role: Role
    let patientID: String
    let eyeSelection: EyeSelection
    let fieldTestMode: FieldTestMode
    let viewingDistanceMeters: Double?
    let optotypeFamily: OptotypeFamily
    let useAppleWatchForScoring: Bool
    let showExaminerOverlay: Bool
    let autoStart: Bool
    let responseScript: [ResponseStep]
    let stepIntervalSeconds: Double
    let initialResponseDelaySeconds: Double

    static func current(from processInfo: ProcessInfo = .processInfo) -> SimulatorLaunchConfiguration? {
        let environment = processInfo.environment

        guard
            let roleValue = environment["VA_ROLE"]?.lowercased(),
            let role = Role(rawValue: roleValue)
        else {
            return nil
        }

        let fieldMode = parseFieldMode(environment["VA_FIELD_MODE"]) ?? .standardChart
        let optotypeFamily = parseOptotypeFamily(environment["VA_OPTOTYPE"]) ?? .tumblingE
        let eyeSelection = parseEyeSelection(environment["VA_EYE"]) ?? .both
        let patientID = environment["VA_PATIENT_ID"] ?? ""
        let viewingDistanceMeters = environment["VA_DISTANCE_METERS"].flatMap(Double.init)
        let useAppleWatchForScoring = parseBoolean(environment["VA_USE_WATCH"])
        let showExaminerOverlay = parseBoolean(environment["VA_SHOW_OVERLAY"])
        let autoStart = parseBoolean(environment["VA_AUTO_START"])
        let responseScript = environment["VA_RESPONSE_SCRIPT"]?
            .split(separator: ",")
            .compactMap { ResponseStep(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) } ?? []
        let stepIntervalSeconds = max(0.3, Double(environment["VA_STEP_INTERVAL"] ?? "") ?? 1.0)
        let initialResponseDelaySeconds = max(0, Double(environment["VA_INITIAL_RESPONSE_DELAY"] ?? "") ?? 0)

        return SimulatorLaunchConfiguration(
            role: role,
            patientID: patientID,
            eyeSelection: eyeSelection,
            fieldTestMode: fieldMode,
            viewingDistanceMeters: viewingDistanceMeters,
            optotypeFamily: optotypeFamily,
            useAppleWatchForScoring: useAppleWatchForScoring,
            showExaminerOverlay: showExaminerOverlay,
            autoStart: autoStart,
            responseScript: responseScript,
            stepIntervalSeconds: stepIntervalSeconds,
            initialResponseDelaySeconds: initialResponseDelaySeconds
        )
    }

    private static func parseFieldMode(_ rawValue: String?) -> FieldTestMode? {
        switch rawValue?.lowercased() {
        case "standard", "standardchart", "withoutperiscope", "direct":
            return .standardChart
        default:
            return nil
        }
    }

    private static func parseOptotypeFamily(_ rawValue: String?) -> OptotypeFamily? {
        switch rawValue?.lowercased() {
        case "tumblinge", "e":
            return .tumblingE
        case "landoltc", "c":
            return .landoltC
        case "snellen", "letters":
            return .snellenLetters
        case "colored", "colour", "color":
            return .coloredChart
        default:
            return nil
        }
    }

    private static func parseEyeSelection(_ rawValue: String?) -> EyeSelection? {
        switch rawValue?.lowercased() {
        case "right", "r":
            return .right
        case "left", "l":
            return .left
        case "both":
            return .both
        default:
            return nil
        }
    }

    private static func parseBoolean(_ rawValue: String?) -> Bool {
        switch rawValue?.lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }
}
