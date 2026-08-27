#if os(watchOS)
import SwiftUI

struct WatchRemoteView: View {
    @ObservedObject var viewModel: WatchRemoteViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if connectivityManager.isReachable {
                    Text(viewModel.remoteStateText)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Correct") { viewModel.send(.responseCorrect) }
                        .buttonStyle(RemoteActionButtonStyle(backgroundColor: .green))

                    Button("Wrong") { viewModel.send(.responseWrong) }
                        .buttonStyle(RemoteActionButtonStyle(backgroundColor: .red))

                    HStack(spacing: 8) {
                        Button("Repeat") { viewModel.send(.repeatItem) }
                            .buttonStyle(RemoteActionButtonStyle(backgroundColor: .orange))
                        Button("Next") { viewModel.send(.nextItem) }
                            .buttonStyle(RemoteActionButtonStyle(backgroundColor: .blue))
                    }

                    Button("End") { viewModel.send(.endTest) }
                        .buttonStyle(RemoteActionButtonStyle(backgroundColor: .gray))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("Not connected")
                            .font(.headline)

                        Button("Connect") {
                            connectivityManager.requestConnection()
                        }
                        .buttonStyle(RemoteActionButtonStyle(backgroundColor: .blue))
                    }
                    .padding(.top, 10)
                }
            }
            .padding()
        }
    }
}

private struct RemoteActionButtonStyle: ButtonStyle {
    let backgroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.horizontal, 4)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.75 : 1.0))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
struct WatchRemoteView_Previews: PreviewProvider {
    static var previews: some View {
        let connectivityManager = WatchConnectivityManager(activateSession: false)

        return WatchRemoteView(
            viewModel: WatchRemoteViewModel(connectivityManager: connectivityManager),
            connectivityManager: connectivityManager
        )
    }
}
#endif
