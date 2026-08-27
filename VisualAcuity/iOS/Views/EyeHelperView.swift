import SwiftUI

/// A pre-test screen that tells the patient which eye to cover, then hands
/// control to the test screen. Uses a subtle pulsing animation on the
/// "covered" eye icon to communicate the instruction without words.
struct EyeHelperView: View {
    @ObservedObject var viewModel: VisualAcuityAppViewModel

    @State private var pulse = false

    private var testingEye: EyeSelection { viewModel.currentTestingEye }
    private var coveredEye: EyeSelection { testingEye == .right ? .left : .right }

    /// The display device passively shows the instruction — only the
    /// examiner on the controller/standalone device clicks "Ready".
    private var isPassiveDisplay: Bool { viewModel.deviceRole == .display }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 36) {
                EyePairVisual(testingEye: testingEye, pulse: pulse)
                    .frame(height: 110)

                VStack(spacing: 10) {
                    Text("Cover your \(coveredEye == .left ? "left" : "right") eye")
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text("Test with your \(testingEye == .left ? "left" : "right") eye")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            if isPassiveDisplay {
                Text("Waiting for examiner…")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 32)
            } else {
                Button {
                    viewModel.startTestForCurrentEye()
                } label: {
                    Text("Ready")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .foregroundStyle(Color(.systemBackground))
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct EyePairVisual: View {
    let testingEye: EyeSelection
    let pulse: Bool

    var body: some View {
        HStack(spacing: 48) {
            eyeIcon(forLeftEye: true)
            eyeIcon(forLeftEye: false)
        }
    }

    @ViewBuilder
    private func eyeIcon(forLeftEye isLeft: Bool) -> some View {
        // The "testing" eye is open; the opposite eye is covered (slashed).
        let isTestingThisEye = (isLeft && testingEye == .left) || (!isLeft && testingEye == .right)

        if isTestingThisEye {
            Image(systemName: "eye")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.primary)
        } else {
            Image(systemName: "eye.slash")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.primary.opacity(pulse ? 1.0 : 0.45))
                .scaleEffect(pulse ? 1.04 : 0.98)
        }
    }
}

@MainActor
struct EyeHelperView_Previews: PreviewProvider {
    static var previews: some View {
        EyeHelperView(
            viewModel: VisualAcuityAppViewModel(
                connectivityManager: WatchConnectivityManager(activateSession: false),
                peerConnectivityManager: PeerConnectivityManager()
            )
        )
    }
}
