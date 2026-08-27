import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: VisualAcuityAppViewModel

    var body: some View {
        Group {
            switch viewModel.screen {
            case .roleSelect:
                RoleSelectionView(viewModel: viewModel)
            case .setup:
                SetupView(
                    viewModel: viewModel,
                    connectivityManager: viewModel.connectivityManager,
                    peerConnectivityManager: viewModel.peerConnectivityManager
                )
            case .eyeHelper:
                EyeHelperView(viewModel: viewModel)
            case .test:
                TestDisplayView(
                    viewModel: viewModel,
                    engine: viewModel.engine,
                    connectivityManager: viewModel.connectivityManager,
                    peerConnectivityManager: viewModel.peerConnectivityManager
                )
            case .results:
                ResultsView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.screen)
        .task {
            viewModel.runLaunchConfigurationIfNeeded()
        }
    }
}

@MainActor
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(
            viewModel: VisualAcuityAppViewModel(
                connectivityManager: WatchConnectivityManager(activateSession: false),
                peerConnectivityManager: PeerConnectivityManager()
            )
        )
    }
}
