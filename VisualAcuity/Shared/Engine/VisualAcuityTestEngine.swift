import Foundation
import Combine

@MainActor
final class VisualAcuityTestEngine: ObservableObject {
    @Published private(set) var session: ActiveTestSession?
    @Published private(set) var result: TestResult?

    func start(configuration: TestConfiguration) {
        let progress = configuration.lines.map { LineProgress(line: $0) }

        session = ActiveTestSession(
            id: UUID(),
            configuration: configuration,
            startedAt: Date(),
            currentLineIndex: 0,
            currentOrientation: configuration.optotypeFamily.usesOrientation ? OptotypeOrientation.random() : .up,
            currentOptotypeSymbol: configuration.optotypeFamily.randomSymbol(),
            lineProgress: progress,
            lastEventDescription: "Awaiting response"
        )
        result = nil
    }

    func reset() {
        session = nil
        result = nil
    }

    func recordCorrect() {
        record(outcome: .correct)
    }

    func recordWrong() {
        record(outcome: .wrong)
    }

    func advanceWithoutScoring() {
        record(outcome: .skipped)
    }

    func repeatCurrentItem() {
        guard var currentSession = session else { return }
        currentSession.lastEventDescription = "Repeat"
        session = currentSession
    }

    func endTest() {
        guard let currentSession = session else { return }
        completeTest(using: currentSession)
    }

    private func record(outcome: ItemOutcome) {
        guard var currentSession = session else { return }

        let lineIndex = currentSession.currentLineIndex
        var lineProgress = currentSession.lineProgress[lineIndex]

        lineProgress.completedItems += 1

        switch outcome {
        case .correct:
            lineProgress.correctCount += 1
        case .wrong:
            lineProgress.wrongCount += 1
        case .skipped:
            lineProgress.skippedCount += 1
        }

        currentSession.lineProgress[lineIndex] = lineProgress
        currentSession.lastEventDescription = outcome.rawValue

        if lineProgress.completedItems >= currentSession.configuration.itemsPerLine {
            let didPass = lineProgress.correctCount >= currentSession.configuration.passThreshold
            currentSession.lineProgress[lineIndex].passed = didPass

            if didPass, lineIndex < currentSession.lineProgress.count - 1 {
                currentSession.currentLineIndex += 1
                currentSession.currentOrientation = currentSession.configuration.optotypeFamily.usesOrientation ? OptotypeOrientation.random() : .up
                currentSession.currentOptotypeSymbol = currentSession.configuration.optotypeFamily.randomSymbol()
                currentSession.lastEventDescription = "\(outcome.rawValue). Passed \(lineProgress.line.displayLabel)"
                session = currentSession
            } else {
                completeTest(using: currentSession)
            }
        } else {
            currentSession.currentOrientation = currentSession.configuration.optotypeFamily.usesOrientation ? OptotypeOrientation.random() : .up
            currentSession.currentOptotypeSymbol = currentSession.configuration.optotypeFamily.randomSymbol()
            session = currentSession
        }
    }

    private func completeTest(using session: ActiveTestSession) {
        result = buildResult(from: session)
        self.session = nil
    }

    private func buildResult(from session: ActiveTestSession) -> TestResult {
        let smallestPassedLine = session.smallestPassedLine
        let firstLineLabel = session.configuration.lines.first?.displayLabel ?? "20/200 (6/60)"
        let distanceText = String(format: "%.2f", session.configuration.viewingDistanceMeters)

        let snellenText: String
        if let smallestPassedLine {
            snellenText = "\(smallestPassedLine.displayLabel) at \(distanceText) m"
        } else {
            snellenText = "Worse than \(firstLineLabel) at \(distanceText) m"
        }

        // Only include lines the examiner actually interacted with.
        let linePerformance: [LineOutcome] = session.lineProgress
            .filter { $0.completedItems > 0 || $0.passed != nil }
            .map { progress in
                LineOutcome(
                    lineLabel: progress.line.displayLabel,
                    correctCount: progress.correctCount,
                    wrongCount: progress.wrongCount,
                    skippedCount: progress.skippedCount,
                    passed: progress.passed
                )
            }

        return TestResult(
            date: .now,
            patientID: session.configuration.displayPatientID,
            eyeSelection: session.configuration.eyeSelection,
            viewingDistanceMeters: session.configuration.viewingDistanceMeters,
            fieldTestMode: session.configuration.fieldTestMode,
            displayMode: session.configuration.displayMode,
            controllerMode: session.configuration.controllerMode,
            optotypeFamily: session.configuration.optotypeFamily,
            correctCount: session.totalCorrectCount,
            wrongCount: session.totalWrongCount,
            skippedCount: session.totalSkippedCount,
            smallestPassedLine: smallestPassedLine,
            snellenText: snellenText,
            linePerformance: linePerformance
        )
    }
}
