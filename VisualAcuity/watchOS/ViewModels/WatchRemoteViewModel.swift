#if os(watchOS)
import Foundation
import Combine

@MainActor
final class WatchRemoteViewModel: ObservableObject {
    @Published private(set) var remoteStateText = "Waiting for test"

    let connectivityManager: WatchConnectivityManager

    init(connectivityManager: WatchConnectivityManager = WatchConnectivityManager()) {
        self.connectivityManager = connectivityManager

        self.connectivityManager.onCommand = { [weak self] command in
            Task { @MainActor in
                self?.handleIncomingCommand(command)
            }
        }
    }

    func send(_ commandType: WatchCommandType) {
        connectivityManager.send(commandType)

        if commandType == .endTest {
            remoteStateText = "Test ended"
        }
    }

    private func handleIncomingCommand(_ command: WatchCommand) {
        switch command.type {
        case .startTest:
            let patient = command.payload["patientID"] ?? "Anonymous"
            let eye = command.payload["eye"] ?? "Unknown eye"
            let optotype = command.payload["optotype"] ?? "Optotype"
            remoteStateText = "\(patient) • \(eye)\n\(optotype)"
        case .endTest:
            remoteStateText = command.payload["result"] ?? "Finished"
        case .responseCorrect, .responseWrong, .repeatItem, .nextItem:
            break
        }
    }
}
#endif
