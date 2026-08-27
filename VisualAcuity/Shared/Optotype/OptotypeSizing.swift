import Foundation

enum OptotypeSizing {
    static func radians(forArcMinutes arcMinutes: Double) -> Double {
        arcMinutes * .pi / (180.0 * 60.0)
    }

    static func viewingDistanceMeters(forPhysicalSizeMillimeters millimeters: Double, line: VisualAcuityLine) -> Double {
        let angleRadians = radians(forArcMinutes: line.optotypeAngleArcMinutes)
        return (millimeters / 1000.0) / (2.0 * tan(angleRadians / 2.0))
    }

    static func physicalSizeMeters(for line: VisualAcuityLine, at viewingDistanceMeters: Double) -> Double {
        let angleRadians = radians(forArcMinutes: line.optotypeAngleArcMinutes)
        return 2.0 * viewingDistanceMeters * tan(angleRadians / 2.0)
    }

    static func physicalSizeMillimeters(for line: VisualAcuityLine, at viewingDistanceMeters: Double) -> Double {
        physicalSizeMeters(for: line, at: viewingDistanceMeters) * 1000.0
    }

    static func strokeWidthMillimeters(for line: VisualAcuityLine, at viewingDistanceMeters: Double) -> Double {
        physicalSizeMillimeters(for: line, at: viewingDistanceMeters) / 5.0
    }

    static func formattedMillimeterLabel(for line: VisualAcuityLine, at viewingDistanceMeters: Double) -> String {
        String(format: "%.1f mm", physicalSizeMillimeters(for: line, at: viewingDistanceMeters))
    }
}
