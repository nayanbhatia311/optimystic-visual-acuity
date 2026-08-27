import SwiftUI

struct CalibrationView: View {
    @ObservedObject var viewModel: VisualAcuityAppViewModel
    @Environment(\.dismiss) private var dismiss

    private let rulerLengthMillimeters = 50.0
    private let squareSizeMillimeters = 10.0
    private let sampleLines = [
        VisualAcuityLine(denominator: 20),
        VisualAcuityLine(denominator: 200),
    ]

    private var metrics: DisplayMetrics {
        viewModel.currentDisplayMetrics
    }

    var body: some View {
        NavigationStack {
            Form {
                ppiSourceSection
                detectedMetricsSection
                visualCheckSection
                optotypeCheckSection
            }
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var ppiSourceSection: some View {
        Section("PPI Source") {
            LabeledContent("Status") {
                Label(
                    metrics.pixelsPerInchSourceLabel,
                    systemImage: metrics.isUsingFallbackPixelsPerInch ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
                )
                .foregroundStyle(metrics.isUsingFallbackPixelsPerInch ? .orange : .green)
                .font(.subheadline.weight(.semibold))
            }

            if metrics.isUsingFallbackPixelsPerInch {
                Text("This display resolution is not in the exact-device catalog. Verify the ruler check on the patient-facing device and add an exact PPI mapping before release validation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("This device matched the app's exact PPI catalog. The physical checks below should still be verified on real hardware.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detectedMetricsSection: some View {
        Section("Detected Display") {
            MetricRow(title: "Device", value: LocalDeviceIdentity.displayName)
            MetricRow(title: "Source", value: metrics.verificationReadout)
            MetricRow(title: "PPI", value: formatted(metrics.pixelsPerInch, decimals: 1))
            MetricRow(title: "Points/mm", value: formatted(metrics.pointsPerMillimeter, decimals: 3))
            MetricRow(title: "Scale", value: "\(formatted(metrics.displayScale, decimals: 1))x")
            MetricRow(title: "Point size", value: formattedSize(metrics.screenSizePoints, decimals: 0))
            MetricRow(title: "Native pixels", value: formattedSize(metrics.nativeSizePixels, decimals: 0))
            MetricRow(title: "Min screen", value: "\(formatted(metrics.minimumScreenDimensionMillimeters, decimals: 1)) mm")
        }
    }

    private var visualCheckSection: some View {
        Section("Visual/mm Check") {
            Text("Measure the black bar with a physical ruler on the patient-facing display. It should be 50 mm long. The square below should be 10 mm on each side.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    CalibrationRulerBar(
                        lengthPoints: points(forMillimeters: rulerLengthMillimeters),
                        label: "\(formatted(rulerLengthMillimeters, decimals: 0)) mm"
                    )

                    CalibrationSquare(
                        sizePoints: points(forMillimeters: squareSizeMillimeters),
                        label: "\(formatted(squareSizeMillimeters, decimals: 0)) mm"
                    )
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var optotypeCheckSection: some View {
        Section("Optotype Size Check") {
            Text("These samples use the same physical sizing path as the test screen at the current setup distance.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(sampleLines) { line in
                CalibrationOptotypeRow(
                    family: viewModel.selectedOptotypeFamily,
                    line: line,
                    distanceMeters: viewModel.parsedViewingDistanceMeters,
                    sizePoints: points(
                        forMillimeters: OptotypeSizing.physicalSizeMillimeters(
                            for: line,
                            at: viewModel.parsedViewingDistanceMeters
                        )
                    )
                )
            }
        }
    }

    private func points(forMillimeters millimeters: Double) -> CGFloat {
        max(1, CGFloat(millimeters) * metrics.pointsPerMillimeter)
    }

    private func formatted(_ value: CGFloat, decimals: Int) -> String {
        formatted(Double(value), decimals: decimals)
    }

    private func formatted(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func formattedSize(_ size: CGSize, decimals: Int) -> String {
        guard size.width > 0, size.height > 0 else { return "Unavailable" }
        return "\(formatted(size.width, decimals: decimals)) x \(formatted(size.height, decimals: decimals))"
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

private struct CalibrationRulerBar: View {
    let lengthPoints: CGFloat
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(.primary)
                    .frame(width: lengthPoints, height: 12)

                HStack {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2, height: 24)
                    Spacer()
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2, height: 24)
                }
                .frame(width: lengthPoints)
            }

            Text(label)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calibration ruler \(label)")
    }
}

private struct CalibrationSquare: View {
    let sizePoints: CGFloat
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .stroke(.primary, lineWidth: 2)
                .frame(width: sizePoints, height: sizePoints)

            Text("\(label) square")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calibration square \(label)")
    }
}

private struct CalibrationOptotypeRow: View {
    let family: OptotypeFamily
    let line: VisualAcuityLine
    let distanceMeters: Double
    let sizePoints: CGFloat

    private var physicalSizeMillimeters: Double {
        OptotypeSizing.physicalSizeMillimeters(for: line, at: distanceMeters)
    }

    private var strokeWidthMillimeters: Double {
        OptotypeSizing.strokeWidthMillimeters(for: line, at: distanceMeters)
    }

    private var symbol: String {
        switch family {
        case .landoltC:
            return "C"
        case .tumblingE, .snellenLetters, .coloredChart:
            return "E"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(line.displayLabel)
                        .font(.headline)
                    Text("\(String(format: "%.2f", distanceMeters)) m distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(String(format: "%.1f", physicalSizeMillimeters)) mm")
                    Text("\(String(format: "%.2f", strokeWidthMillimeters)) mm stroke")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .monospacedDigit()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                OptotypeView(
                    family: family,
                    symbol: symbol,
                    orientation: .right,
                    size: sizePoints,
                    foregroundColor: .primary
                )
                .padding(.vertical, 4)
                .frame(minWidth: sizePoints, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
struct CalibrationView_Previews: PreviewProvider {
    static var previews: some View {
        CalibrationView(
            viewModel: VisualAcuityAppViewModel(
                connectivityManager: WatchConnectivityManager(activateSession: false),
                peerConnectivityManager: PeerConnectivityManager()
            )
        )
    }
}
