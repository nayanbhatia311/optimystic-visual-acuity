#if os(watchOS)
import SwiftUI

@main
struct VisualAcuityWatchApp: App {
    @StateObject private var viewModel = WatchRemoteViewModel()

    var body: some Scene {
        WindowGroup {
            WatchRemoteView(
                viewModel: viewModel,
                connectivityManager: viewModel.connectivityManager
            )
        }
    }
}
#endif
