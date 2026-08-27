import SwiftUI

struct WatchRemoteView: View {
    @ObservedObject var viewModel: WatchRemoteViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                if !viewModel.isTestActive {
                    connectionHeader
                }

                if viewModel.isTestActive {
                    activeTest
                } else if connectivityManager.isReachable {
                    connectedIdle
                } else {
                    disconnectedPrompt
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
        }
    }

    private var connectionHeader: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(connectivityManager.isReachable ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(connectivityManager.isReachable ? "iPhone connected" : "Waiting for iPhone")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.white.opacity(0.08), in: Capsule())
    }

    // MARK: – States

    private var activeTest: some View {
        VStack(spacing: 7) {
            Text(viewModel.statusLine)
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 32)
                .padding(.horizontal, 8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))

            HStack(spacing: 6) {
                RemoteButton(
                    systemImage: "checkmark",
                    title: "Correct",
                    color: .green,
                    isHighlighted: viewModel.highlightedSimulatorCommand == .responseCorrect
                ) {
                    viewModel.send(.responseCorrect)
                }
                RemoteButton(
                    systemImage: "xmark",
                    title: "Wrong",
                    color: .red,
                    isHighlighted: viewModel.highlightedSimulatorCommand == .responseWrong
                ) {
                    viewModel.send(.responseWrong)
                }
            }

            HStack(spacing: 6) {
                RemoteButton(
                    systemImage: "arrow.counterclockwise",
                    title: "Repeat",
                    color: .orange,
                    isHighlighted: viewModel.highlightedSimulatorCommand == .repeatItem
                ) {
                    viewModel.send(.repeatItem)
                }
                RemoteButton(
                    systemImage: "arrow.right",
                    title: "Next",
                    color: .blue,
                    isHighlighted: viewModel.highlightedSimulatorCommand == .nextItem
                ) {
                    viewModel.send(.nextItem)
                }
            }

            RemoteButton(
                systemImage: "stop.fill",
                title: "End test",
                color: .gray,
                isHighlighted: viewModel.highlightedSimulatorCommand == .endTest
            ) {
                viewModel.send(.endTest)
            }
        }
    }

    private var connectedIdle: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.green)

            VStack(spacing: 3) {
                Text("Ready to score")
                    .font(.headline)

                Text("Set up and start the test\non your iPhone")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var disconnectedPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Not connected")
                .font(.headline)

            Button {
                connectivityManager.requestConnection()
            } label: {
                Text("Connect")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 10)
    }
}

private struct RemoteButton: View {
    let systemImage: String
    let title: String
    let color: Color
    let isHighlighted: Bool
    let action: () -> Void

    init(
        systemImage: String,
        title: String,
        color: Color,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.color = color
        self.isHighlighted = isHighlighted
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 43)
        }
        .buttonStyle(.plain)
        .background(color)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white, lineWidth: isHighlighted ? 4 : 0)
        }
        .scaleEffect(isHighlighted ? 1.04 : 1)
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        .accessibilityLabel(title)
    }
}

private struct WatchRemotePreview: View {
    @StateObject private var vm = WatchRemoteViewModel()
    var body: some View {
        WatchRemoteView(viewModel: vm, connectivityManager: vm.connectivityManager)
    }
}

struct WatchRemoteView_Previews: PreviewProvider {
    static var previews: some View {
        WatchRemotePreview()
    }
}
