import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var isReachable = false
    @Published private(set) var connectionStatusText = "Connecting..."
    @Published private(set) var lastReceivedCommand: WatchCommand?

    var onCommand: ((WatchCommand) -> Void)?

    private let session: WCSession = .default

    override init() {
        super.init()
        session.delegate = self
        session.activate()
        refreshStatus()
    }

    /// Explicitly nudge the session from the Watch side. Called from the
    /// "Connect" button so the user's intent is unambiguous — no dependency
    /// on the iPhone being open to kick things off.
    func requestConnection() {
        switch session.activationState {
        case .notActivated, .inactive:
            session.activate()
        case .activated:
            if session.isReachable {
                session.sendMessage(["type": "ping"], replyHandler: nil, errorHandler: nil)
            } else {
                try? session.updateApplicationContext(["type": "ping"])
            }
        @unknown default:
            session.activate()
        }

        refreshStatus()
    }

    func send(_ type: WatchCommandType, payload: [String: String] = [:]) {
        send(WatchCommand(type: type, payload: payload))
    }

    func send(_ command: WatchCommand) {
        let message = command.message

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.connectionStatusText = "Send failed: \(error.localizedDescription)"
                }
            }
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                connectionStatusText = "Queue failed: \(error.localizedDescription)"
            }
        }
    }

    private func refreshStatus() {
        isReachable = session.isReachable

        switch session.activationState {
        case .notActivated:
            connectionStatusText = "Activating..."
        case .inactive:
            connectionStatusText = "Inactive"
        case .activated:
            connectionStatusText = session.isReachable ? "Connected to iPhone" : "Open the iPhone app"
        @unknown default:
            connectionStatusText = "Unknown state"
        }
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        refreshStatus()

        // Ignore reachability pings used just to establish the link.
        if let type = message["type"] as? String, type == "ping" {
            return
        }

        guard let command = WatchCommand(message: message) else { return }
        lastReceivedCommand = command
        onCommand?(command)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.connectionStatusText = "Activation failed: \(error.localizedDescription)"
            }
            self.refreshStatus()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshStatus()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleIncomingMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.handleIncomingMessage(applicationContext)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.refreshStatus()
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
