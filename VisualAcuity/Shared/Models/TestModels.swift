import Foundation

enum EyeSelection: String, CaseIterable, Identifiable, Codable {
    case right = "Right"
    case left = "Left"
    case both = "Both"

    var id: String { rawValue }
}

enum OptotypeOrientation: String, CaseIterable, Codable {
    case up
    case down
    case left
    case right

    var rotationDegrees: Double {
        // The vector Tumbling E and Landolt C are authored with their open side
        // facing right. Map the stored orientation to the rendered response
        // direction instead of treating `.up` as the zero-rotation state.
        switch self {
        case .up:
            return 270
        case .right:
            return 0
        case .down:
            return 90
        case .left:
            return 180
        }
    }

    var accessibilityLabel: String {
        rawValue.capitalized
    }

    static func random() -> OptotypeOrientation {
        allCases.randomElement() ?? .up
    }
}

enum FieldTestMode: String, CaseIterable, Identifiable, Codable {
    // Future periscope support can come back here once the dedicated optical workflow is ready.
    case standardChart = "Standard Chart"

    var id: String { rawValue }

    var helperText: String {
        "Use the measured patient-to-screen distance for a standard chart setup."
    }
}

enum PatientDisplayMode: String, CaseIterable, Identifiable, Codable {
    case currentDevice = "This Device"
    case peerDevice = "Another Apple Device"

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.currentDevice.rawValue:
            self = .currentDevice
        case Self.peerDevice.rawValue, "Another iPhone/iPad", "Mac":
            self = .peerDevice
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported patient display mode: \(rawValue)"
            )
        }
    }
}

enum ExaminerControlMode: String, CaseIterable, Identifiable, Codable {
    case localDevice = "This Device"
    case appleWatch = "Apple Watch"
    case peerDevice = "Another Apple Device"

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.localDevice.rawValue:
            self = .localDevice
        case Self.appleWatch.rawValue:
            self = .appleWatch
        case Self.peerDevice.rawValue, "Another iPhone/iPad", "Mac":
            self = .peerDevice
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported examiner control mode: \(rawValue)"
            )
        }
    }
}

enum OptotypeFamily: String, CaseIterable, Identifiable, Codable {
    case tumblingE = "Tumbling E"
    case landoltC = "Landolt C"
    case snellenLetters = "Snellen Letters"
    case coloredChart = "Colored Chart"

    private static let snellenLetterSet = ["C", "D", "E", "F", "L", "O", "P", "T", "Z"]

    var id: String { rawValue }

    var isImplementedNow: Bool {
        self == .tumblingE || self == .landoltC
    }

    var usesOrientation: Bool {
        self == .tumblingE || self == .landoltC
    }

    var helperText: String {
        switch self {
        case .tumblingE:
            return "Paper-aligned 5x5 directional optotype for illiterate or non-verbal patients."
        case .landoltC:
            return "Paper-aligned ring-gap optotype for illiterate or non-verbal patients."
        case .snellenLetters:
            return "Reserved until a calibrated vector letter set is available."
        case .coloredChart:
            return "Paper mentions a colored chart variant; this is reserved for a future pass."
        }
    }

    func randomSymbol() -> String {
        switch self {
        case .tumblingE:
            return "E"
        case .landoltC:
            return "C"
        case .snellenLetters:
            return Self.snellenLetterSet.randomElement() ?? "E"
        case .coloredChart:
            return "E"
        }
    }
}

struct VisualAcuityLine: Identifiable, Hashable, Codable {
    let denominator: Int

    var id: String { imperialLabel }

    var imperialLabel: String {
        "20/\(denominator)"
    }

    var metricDenominator: Int {
        Int((Double(denominator) * 6.0 / 20.0).rounded())
    }

    var metricLabel: String {
        "6/\(metricDenominator)"
    }

    var displayLabel: String {
        "\(imperialLabel) (\(metricLabel))"
    }

    var decimalAcuity: Double {
        20.0 / Double(denominator)
    }

    var logMAR: Double {
        log10(Double(denominator) / 20.0)
    }

    var optotypeAngleArcMinutes: Double {
        5.0 * (Double(denominator) / 20.0)
    }

    static let paperReferenceLines: [VisualAcuityLine] = [
        VisualAcuityLine(denominator: 200),
        VisualAcuityLine(denominator: 120),
        VisualAcuityLine(denominator: 80),
        VisualAcuityLine(denominator: 40),
        VisualAcuityLine(denominator: 30),
        VisualAcuityLine(denominator: 20),
    ]
}

enum ItemOutcome: String, Codable {
    case correct = "Correct"
    case wrong = "Wrong"
    case skipped = "Next"
}

struct TestConfiguration: Equatable {
    static let defaultStandardDistanceMeters = 3.0
    static let defaultItemsPerLine = 5
    static let defaultPassThreshold = 3

    var patientID: String
    var eyeSelection: EyeSelection
    var viewingDistanceMeters: Double
    var fieldTestMode: FieldTestMode
    var displayMode: PatientDisplayMode
    var controllerMode: ExaminerControlMode
    var optotypeFamily: OptotypeFamily
    var showExaminerOverlay: Bool
    var itemsPerLine: Int
    var passThreshold: Int
    var lines: [VisualAcuityLine]

    var displayPatientID: String {
        let trimmed = patientID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Anonymous" : trimmed
    }

    var distanceLabel: String {
        String(format: "%.2f m", viewingDistanceMeters)
    }

    static let mvp = TestConfiguration(
        patientID: "",
        eyeSelection: .right,
        viewingDistanceMeters: defaultStandardDistanceMeters,
        fieldTestMode: .standardChart,
        displayMode: .currentDevice,
        controllerMode: .localDevice,
        optotypeFamily: .tumblingE,
        showExaminerOverlay: false,
        itemsPerLine: defaultItemsPerLine,
        passThreshold: defaultPassThreshold,
        lines: VisualAcuityLine.paperReferenceLines
    )
}

struct LineProgress: Identifiable, Hashable {
    let line: VisualAcuityLine
    var completedItems: Int = 0
    var correctCount: Int = 0
    var wrongCount: Int = 0
    var skippedCount: Int = 0
    var passed: Bool?

    var id: String { line.id }
}

struct ActiveTestSession: Identifiable, Equatable {
    let id: UUID
    let configuration: TestConfiguration
    let startedAt: Date
    var currentLineIndex: Int
    var currentOrientation: OptotypeOrientation
    var currentOptotypeSymbol: String
    var lineProgress: [LineProgress]
    var lastEventDescription: String

    var currentLine: VisualAcuityLine {
        lineProgress[currentLineIndex].line
    }

    var currentLineProgress: LineProgress {
        lineProgress[currentLineIndex]
    }

    var currentItemNumber: Int {
        min(currentLineProgress.completedItems + 1, configuration.itemsPerLine)
    }

    var currentPhysicalOptotypeSizeMillimeters: Double {
        OptotypeSizing.physicalSizeMillimeters(
            for: currentLine,
            at: configuration.viewingDistanceMeters
        )
    }

    var totalCorrectCount: Int {
        lineProgress.reduce(0) { $0 + $1.correctCount }
    }

    var totalWrongCount: Int {
        lineProgress.reduce(0) { $0 + $1.wrongCount }
    }

    var totalSkippedCount: Int {
        lineProgress.reduce(0) { $0 + $1.skippedCount }
    }

    var smallestPassedLine: VisualAcuityLine? {
        lineProgress.compactMap { progress in
            progress.passed == true ? progress.line : nil
        }.last
    }
}

struct LineOutcome: Codable, Equatable, Identifiable {
    let lineLabel: String
    let correctCount: Int
    let wrongCount: Int
    let skippedCount: Int
    let passed: Bool?

    var id: String { lineLabel }
}

struct TestResult: Codable, Equatable {
    let date: Date
    let patientID: String
    let eyeSelection: EyeSelection
    let viewingDistanceMeters: Double
    let fieldTestMode: FieldTestMode
    let displayMode: PatientDisplayMode
    let controllerMode: ExaminerControlMode
    let optotypeFamily: OptotypeFamily
    let correctCount: Int
    let wrongCount: Int
    let skippedCount: Int
    let smallestPassedLine: VisualAcuityLine?
    let snellenText: String
    let linePerformance: [LineOutcome]

    init(
        date: Date = .now,
        patientID: String,
        eyeSelection: EyeSelection,
        viewingDistanceMeters: Double,
        fieldTestMode: FieldTestMode,
        displayMode: PatientDisplayMode,
        controllerMode: ExaminerControlMode,
        optotypeFamily: OptotypeFamily,
        correctCount: Int,
        wrongCount: Int,
        skippedCount: Int,
        smallestPassedLine: VisualAcuityLine?,
        snellenText: String,
        linePerformance: [LineOutcome] = []
    ) {
        self.date = date
        self.patientID = patientID
        self.eyeSelection = eyeSelection
        self.viewingDistanceMeters = viewingDistanceMeters
        self.fieldTestMode = fieldTestMode
        self.displayMode = displayMode
        self.controllerMode = controllerMode
        self.optotypeFamily = optotypeFamily
        self.correctCount = correctCount
        self.wrongCount = wrongCount
        self.skippedCount = skippedCount
        self.smallestPassedLine = smallestPassedLine
        self.snellenText = snellenText
        self.linePerformance = linePerformance
    }
}

/// A persisted test session — may contain one or both eye results.
struct StoredSession: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let patientID: String
    let rightEye: TestResult?
    let leftEye: TestResult?

    var summary: String {
        switch (rightEye, leftEye) {
        case (.some(let r), .some(let l)):
            return "R: \(r.snellenText) · L: \(l.snellenText)"
        case (.some(let r), .none):
            return "R: \(r.snellenText)"
        case (.none, .some(let l)):
            return "L: \(l.snellenText)"
        case (.none, .none):
            return "No result"
        }
    }
}

extension ActiveTestSession {
    static let preview = ActiveTestSession(
        id: UUID(),
        configuration: .mvp,
        startedAt: .now,
        currentLineIndex: 2,
        currentOrientation: .left,
        currentOptotypeSymbol: "E",
        lineProgress: TestConfiguration.mvp.lines.enumerated().map { index, line in
            LineProgress(
                line: line,
                completedItems: index < 2 ? 5 : 2,
                correctCount: index < 2 ? 4 : 1,
                wrongCount: index < 2 ? 1 : 1,
                skippedCount: 0,
                passed: index < 2 ? true : nil
            )
        },
        lastEventDescription: "Correct"
    )
}

extension TestResult {
    static let preview = TestResult(
        date: .now,
        patientID: "P-1001",
        eyeSelection: .right,
        viewingDistanceMeters: 3.0,
        fieldTestMode: .standardChart,
        displayMode: .currentDevice,
        controllerMode: .localDevice,
        optotypeFamily: .tumblingE,
        correctCount: 14,
        wrongCount: 1,
        skippedCount: 0,
        smallestPassedLine: VisualAcuityLine.paperReferenceLines[3],
        snellenText: "20/40 (6/12) at 1.00 m",
        linePerformance: []
    )
}
