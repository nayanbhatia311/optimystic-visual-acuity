import SwiftUI

@main
struct VisualAcuityWatchApp: App {
    @StateObject private var viewModel = WatchRemoteViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchRemoteView(
                    viewModel: viewModel,
                    connectivityManager: viewModel.connectivityManager
                )
            }
        }
    }
}
