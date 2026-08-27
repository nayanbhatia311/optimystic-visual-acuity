import SwiftUI
#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

struct TestDisplayView: View {
    @ObservedObject var viewModel: VisualAcuityAppViewModel
    @ObservedObject var engine: VisualAcuityTestEngine
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var peerConnectivityManager: PeerConnectivityManager

    @State private var showExitConfirm = false
    @State private var isCalibrationPresented = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.runtimeMode == .peerController {
                    controllerStatusView(in: geometry.size)
                } else if let remoteDisplayState = viewModel.remoteDisplayState {
                    OptotypeView(
                        family: remoteDisplayState.optotypeFamily,
                        symbol: remoteDisplayState.symbol,
                        orientation: remoteDisplayState.orientation,
                        size: viewModel.remoteOptotypeSize(in: geometry.size)
                    )
                } else if let session = engine.session {
                    OptotypeView(
                        family: session.configuration.optotypeFamily,
                        symbol: session.currentOptotypeSymbol,
                        orientation: session.currentOrientation,
                        size: viewModel.optotypeSize(in: geometry.size)
                    )
                } else {
                    waitingView
                }
            }
            .background {
                WindowScreenMetricsReader { screen in
                    viewModel.updateCurrentDisplayMetrics(DisplayMetrics.current(for: screen))
                }
            }
            .overlay(alignment: .bottom) {
                if let _ = engine.session,
                   viewModel.runtimeMode != .peerController,
                   viewModel.showsLocalExaminerControls {
                    localControls
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Subtle exit control — two-tap to confirm to avoid accidents.
                Button {
                    showExitConfirm = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exit test")
            }
            .overlay(alignment: .topLeading) {
                if showsCalibrationButton {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            isCalibrationPresented = true
                        } label: {
                            Image(systemName: "ruler")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Calibration")

                        Text(viewModel.currentDisplayMetrics.verificationReadout)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.08), in: Capsule())
                            .accessibilityLabel("Display metrics \(viewModel.currentDisplayMetrics.verificationReadout)")
                    }
                    .padding(16)
                }
            }
            // Triple-tap anywhere on screen as a secondary exit gesture.
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                showExitConfirm = true
            }
        }
        .statusBarHidden(true)
        .confirmationDialog(
            "Exit test?",
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button("Exit", role: .destructive) {
                viewModel.exitTestEarly()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Progress will not be saved.")
        }
        .sheet(isPresented: $isCalibrationPresented) {
            CalibrationView(viewModel: viewModel)
        }
    }

    private var showsCalibrationButton: Bool {
        viewModel.deviceRole == .display && viewModel.remoteDisplayState == nil
    }

    private var waitingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.8))

            Text("Ready")
                .font(.title3)
                .foregroundStyle(.white)

            Text(peerConnectivityManager.displayWaitingStatusText)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            if let remoteResultText = viewModel.remoteResultText {
                Text(remoteResultText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private func controllerStatusView(in availableSize: CGSize) -> some View {
        if let session = engine.session {
            VStack(spacing: 24) {
                Spacer(minLength: 8)

                Text(session.currentLine.displayLabel)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)

                Text(currentEyeLabel(for: session))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                controllerPreviewCard(session: session, in: availableSize)

                if viewModel.showsLocalExaminerControls {
                    localControls
                }

                Spacer(minLength: 8)
            }
            .multilineTextAlignment(.center)
            .padding()
        } else {
            waitingView
        }
    }

    private func currentEyeLabel(for session: ActiveTestSession) -> String {
        let eye = session.configuration.eyeSelection
        switch eye {
        case .right: return "Right eye"
        case .left: return "Left eye"
        case .both: return "Both eyes"
        }
    }

    private func controllerPreviewCard(session: ActiveTestSession, in availableSize: CGSize) -> some View {
        OptotypeView(
            family: session.configuration.optotypeFamily,
            symbol: session.currentOptotypeSymbol,
            orientation: session.currentOrientation,
            size: controllerPreviewSize(for: session, in: availableSize),
            foregroundColor: .black
        )
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private var localControls: some View {
        VStack(spacing: 16) {
            // Primary scoring row: big tick ✓ and cross ✗ — used on every item.
            HStack(spacing: 20) {
                primaryScoreButton(
                    systemImage: "checkmark",
                    color: .green,
                    accessibilityLabel: "Correct",
                    action: viewModel.markCorrect
                )
                primaryScoreButton(
                    systemImage: "xmark",
                    color: .red,
                    accessibilityLabel: "Wrong",
                    action: viewModel.markWrong
                )
            }

            // Secondary row: repeat / next / end. Used far less often, so kept small.
            HStack(spacing: 18) {
                secondaryControlButton(title: "Repeat", systemImage: "arrow.counterclockwise", action: viewModel.repeatItem)
                secondaryControlButton(title: "Next", systemImage: "forward", action: viewModel.advanceWithoutScoring)
                secondaryControlButton(title: "End", systemImage: "stop", action: viewModel.endTest)
            }
        }
    }

    private func primaryScoreButton(
        systemImage: String,
        color: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 84)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(color)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func secondaryControlButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    /// Controller preview is purely a reference so the examiner sees the
    /// current optotype shape/orientation — its size should be consistent
    /// regardless of the patient-to-display distance. Only the actual
    /// display device scales to the physical optotype size.
    private func controllerPreviewSize(for session: ActiveTestSession, in availableSize: CGSize) -> CGFloat {
        let minDimension = min(availableSize.width, availableSize.height)
        return minDimension * 0.28
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
private struct WindowScreenMetricsReader: UIViewRepresentable {
    let onChange: (UIScreen?) -> Void

    func makeUIView(context: Context) -> WindowScreenMetricsView {
        WindowScreenMetricsView(onChange: onChange)
    }

    func updateUIView(_ uiView: WindowScreenMetricsView, context: Context) {
        uiView.onChange = onChange
        uiView.reportIfNeeded()
    }

    final class WindowScreenMetricsView: UIView {
        var onChange: (UIScreen?) -> Void

        private var lastSignature: String?
        private var screenPollTimer: Timer?

        init(onChange: @escaping (UIScreen?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            stopScreenPolling()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if window == nil {
                stopScreenPolling()
            } else {
                startScreenPolling()
            }

            reportIfNeeded()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            reportIfNeeded()
        }

        func reportIfNeeded() {
            let screen = window?.screen
            let signature = signature(for: screen)
            guard signature != lastSignature else { return }

            lastSignature = signature
            onChange(screen)
        }

        private func startScreenPolling() {
            #if targetEnvironment(macCatalyst)
            guard screenPollTimer == nil else { return }

            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.reportIfNeeded()
            }
            RunLoop.main.add(timer, forMode: .common)
            screenPollTimer = timer
            #endif
        }

        private func stopScreenPolling() {
            screenPollTimer?.invalidate()
            screenPollTimer = nil
        }

        private func signature(for screen: UIScreen?) -> String {
            guard let screen else { return "none" }

            return [
                String(describing: ObjectIdentifier(screen)),
                String(describing: screen.bounds),
                String(describing: screen.nativeBounds),
                String(format: "%.3f", screen.scale),
            ].joined(separator: "|")
        }
    }
}
#endif

@MainActor
struct TestDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        let engine = VisualAcuityTestEngine()
        let connectivityManager = WatchConnectivityManager(activateSession: false)
        let peerConnectivityManager = PeerConnectivityManager()
        engine.start(configuration: .mvp)

        return TestDisplayView(
            viewModel: VisualAcuityAppViewModel(
                engine: engine,
                connectivityManager: connectivityManager,
                peerConnectivityManager: peerConnectivityManager
            ),
            engine: engine,
            connectivityManager: connectivityManager,
            peerConnectivityManager: peerConnectivityManager
        )
    }
}
