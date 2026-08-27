import Foundation
import UIKit

enum ResultPDFExporter {
    /// Export a single eye's result as a PDF.
    static func makeTemporaryFile(for result: TestResult) throws -> URL {
        try makeTemporaryFile(session: StoredSession(
            id: UUID(),
            date: result.date,
            patientID: result.patientID,
            rightEye: result.eyeSelection == .left ? nil : result,
            leftEye: result.eyeSelection == .left ? result : nil
        ))
    }

    /// Export a full session (one or both eyes) as a single PDF.
    static func makeTemporaryFile(session: StoredSession) throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: session.date).replacingOccurrences(of: ":", with: "-")
        let patientSlug = sanitize(session.patientID.isEmpty ? "anonymous" : session.patientID)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Optimystic-\(patientSlug)-\(timestamp)")
            .appendingPathExtension("pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url) { context in
            context.beginPage()

            let horizontalInset: CGFloat = 40
            let maxWidth = pageRect.width - (horizontalInset * 2)
            var y: CGFloat = 40

            y += draw(
                "Optimystic — Visual Acuity Report",
                at: CGPoint(x: horizontalInset, y: y),
                width: maxWidth,
                font: .boldSystemFont(ofSize: 24)
            )
            y += 8

            let dateString = DateFormatter.localizedString(from: session.date, dateStyle: .medium, timeStyle: .short)
            y += draw(
                "Patient: \(session.patientID.isEmpty ? "Anonymous" : session.patientID)   ·   \(dateString)",
                at: CGPoint(x: horizontalInset, y: y),
                width: maxWidth,
                font: .systemFont(ofSize: 12),
                color: .darkGray
            )
            y += 18

            if let right = session.rightEye {
                y = drawEyeSection(title: "Right Eye", result: right, at: y, inset: horizontalInset, width: maxWidth)
                y += 18
            }

            if let left = session.leftEye {
                y = drawEyeSection(title: "Left Eye", result: left, at: y, inset: horizontalInset, width: maxWidth)
                y += 18
            }

            // Prototype disclaimer at the bottom.
            y += 8
            y += draw(
                PrototypeContent.prototypeDisclaimer,
                at: CGPoint(x: horizontalInset, y: y),
                width: maxWidth,
                font: .systemFont(ofSize: 11),
                color: .darkGray
            )
            y += 8

            y += draw(
                PrototypeContent.professionalFollowUp,
                at: CGPoint(x: horizontalInset, y: y),
                width: maxWidth,
                font: .systemFont(ofSize: 11),
                color: .darkGray
            )
            y += 8

            _ = draw(
                PrototypeContent.sourceCitationText,
                at: CGPoint(x: horizontalInset, y: y),
                width: maxWidth,
                font: .systemFont(ofSize: 9),
                color: .darkGray
            )
        }

        return url
    }

    private static func drawEyeSection(
        title: String,
        result: TestResult,
        at y: CGFloat,
        inset: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        var y = y

        y += draw(
            title,
            at: CGPoint(x: inset, y: y),
            width: width,
            font: .boldSystemFont(ofSize: 15)
        )
        y += 4

        y += draw(
            result.snellenText,
            at: CGPoint(x: inset, y: y),
            width: width,
            font: .systemFont(ofSize: 14, weight: .semibold)
        )
        y += 10

        let meta: [(String, String)] = [
            ("Distance", String(format: "%.2f m", result.viewingDistanceMeters)),
            ("Optotype", result.optotypeFamily.rawValue),
            ("Smallest passed line", result.smallestPassedLine?.displayLabel ?? "None"),
            ("Correct", "\(result.correctCount)"),
            ("Wrong", "\(result.wrongCount)"),
            ("Skipped", "\(result.skippedCount)")
        ]

        for row in meta {
            y += draw(
                "\(row.0): \(row.1)",
                at: CGPoint(x: inset, y: y),
                width: width,
                font: .systemFont(ofSize: 11)
            )
            y += 3
        }

        // Per-line breakdown table.
        if !result.linePerformance.isEmpty {
            y += 8
            y += draw(
                "Per-line performance",
                at: CGPoint(x: inset, y: y),
                width: width,
                font: .systemFont(ofSize: 11, weight: .semibold)
            )
            y += 4

            // Header.
            drawTableRow(
                columns: ["Line", "✓", "✗", "Next", "Pass"],
                at: y,
                inset: inset,
                width: width,
                isHeader: true
            )
            y += 14

            for line in result.linePerformance {
                let passText: String
                switch line.passed {
                case .some(true): passText = "Yes"
                case .some(false): passText = "No"
                case .none: passText = "—"
                }

                drawTableRow(
                    columns: [
                        line.lineLabel,
                        "\(line.correctCount)",
                        "\(line.wrongCount)",
                        "\(line.skippedCount)",
                        passText
                    ],
                    at: y,
                    inset: inset,
                    width: width,
                    isHeader: false
                )
                y += 13
            }
        }

        return y
    }

    private static func drawTableRow(
        columns: [String],
        at y: CGFloat,
        inset: CGFloat,
        width: CGFloat,
        isHeader: Bool
    ) {
        // 5 columns: Line (wide), ✓, ✗, Next, Pass
        let widths: [CGFloat] = [0.40, 0.13, 0.13, 0.17, 0.17].map { $0 * width }
        var x = inset
        let font: UIFont = isHeader
            ? .systemFont(ofSize: 10, weight: .semibold)
            : .systemFont(ofSize: 10)
        let color: UIColor = isHeader ? .darkGray : .black

        for (index, column) in columns.enumerated() {
            _ = draw(
                column,
                at: CGPoint(x: x, y: y),
                width: widths[index] - 4,
                font: font,
                color: color
            )
            x += widths[index]
        }
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { partialResult, character in
                partialResult.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    @discardableResult
    private static func draw(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let rect = CGRect(x: point.x, y: point.y, width: width, height: .greatestFiniteMagnitude)
        let box = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        NSString(string: text).draw(
            in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(box.height)),
            withAttributes: attributes
        )

        return ceil(box.height)
    }
}
