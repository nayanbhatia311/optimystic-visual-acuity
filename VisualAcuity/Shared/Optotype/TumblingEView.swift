import SwiftUI

struct OptotypeView: View {
    let family: OptotypeFamily
    let symbol: String
    let orientation: OptotypeOrientation
    let size: CGFloat
    var foregroundColor: Color = .white

    var body: some View {
        Group {
            switch family {
            case .tumblingE:
                TumblingEOptotype()
                    .fill(foregroundColor)
                    .rotationEffect(.degrees(orientation.rotationDegrees))
            case .landoltC:
                LandoltCOptotype(orientation: orientation)
                    .stroke(
                        foregroundColor,
                        style: StrokeStyle(
                            lineWidth: size / 5.0,
                            lineCap: .butt,
                            lineJoin: .miter
                        )
                    )
            case .snellenLetters, .coloredChart:
                Text(symbol)
                    .font(.system(size: size * 0.92, weight: .bold, design: .serif))
                    .foregroundStyle(family == .coloredChart ? .yellow : foregroundColor)
                    .minimumScaleFactor(0.2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(family.rawValue) \(symbol) \(orientation.accessibilityLabel)")
    }
}

struct TumblingEOptotype: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let unit = side / 5.0
        let origin = CGPoint(
            x: rect.midX - side / 2.0,
            y: rect.midY - side / 2.0
        )

        var path = Path()
        path.addRect(CGRect(x: origin.x, y: origin.y, width: unit, height: side))
        path.addRect(CGRect(x: origin.x, y: origin.y, width: unit * 4.0, height: unit))
        path.addRect(CGRect(x: origin.x, y: origin.y + (unit * 2.0), width: unit * 3.0, height: unit))
        path.addRect(CGRect(x: origin.x, y: origin.y + (unit * 4.0), width: unit * 4.0, height: unit))
        return path
    }
}

struct LandoltCOptotype: Shape {
    let orientation: OptotypeOrientation

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let unit = side / 5.0
        let square = CGRect(x: rect.midX - side / 2.0, y: rect.midY - side / 2.0, width: side, height: side)
        let center = CGPoint(x: square.midX, y: square.midY)
        let radius = (side / 2.0) - (unit / 2.0)
        let gapAngleDegrees = 2.0 * asin(0.25) * 180.0 / .pi
        let halfGap = gapAngleDegrees / 2.0

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(halfGap),
            endAngle: .degrees(360.0 - halfGap),
            clockwise: false,
            transform: rotationTransform(for: orientation, in: square)
        )
        return path
    }

    private func rotationTransform(for orientation: OptotypeOrientation, in rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .rotated(by: CGFloat(orientation.rotationDegrees * .pi / 180.0))
            .translatedBy(x: -rect.midX, y: -rect.midY)
    }
}

struct TumblingEView: View {
    let orientation: OptotypeOrientation
    let size: CGFloat

    var body: some View {
        OptotypeView(
            family: .tumblingE,
            symbol: "E",
            orientation: orientation,
            size: size
        )
    }
}

@MainActor
struct TumblingEView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                OptotypeView(
                    family: .tumblingE,
                    symbol: "E",
                    orientation: .right,
                    size: 180
                )
                OptotypeView(
                    family: .landoltC,
                    symbol: "C",
                    orientation: .down,
                    size: 180
                )
            }
        }
    }
}
