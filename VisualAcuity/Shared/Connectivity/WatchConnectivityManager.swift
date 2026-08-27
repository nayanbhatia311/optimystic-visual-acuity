import Foundation
import Combine

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var isReachable = false
    @Published private(set) var connectionStatusText = "Not connected"
    @Published private(set) var lastReceivedCommand: WatchCommand?

    var onCommand: ((WatchCommand) -> Void)?

    #if canImport(WatchConnectivity)
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var reactivateTask: Task<Void, Never>?
    #endif

    init(activateSession: Bool = true) {
        super.init()

        if activateSession {
            activate()
        } else {
            connectionStatusText = "Preview"
        }
    }

    func activate() {
        #if canImport(WatchConnectivity)
        guard let session else {
            connectionStatusText = "Unavailable"
            return
        }

        session.delegate = self
        session.activate()
        refreshStatus(for: session)
        #else
        connectionStatusText = "Unavailable"
        #endif
    }

    /// Explicitly nudge the session. Called from the Watch "Connect" button
    /// so the user's intent to pair is unambiguous — no dependency on the
    /// iPhone being open to kick things off.
    func requestConnection() {
        #if canImport(WatchConnectivity)
        guard let session else { return }

        switch session.activationState {
        case .notActivated, .inactive:
            session.activate()
        case .activated:
            // Send a lightweight ping so iOS surfaces the link state.
            if session.isReachable {
                session.sendMessage(["type": "ping"], replyHandler: nil, errorHandler: nil)
            } else {
                // Queue a context update — wakes iPhone side next time it opens.
                try? session.updateApplicationContext(["type": "ping"])
            }
        @unknown default:
            session.activate()
        }

        refreshStatus(for: session)
        #endif
    }

    func send(_ type: WatchCommandType, payload: [String: String] = [:]) {
        send(WatchCommand(type: type, payload: payload))
    }

    func send(_ command: WatchCommand) {
        #if canImport(WatchConnectivity)
        guard let session else {
            connectionStatusText = "Unavailable"
            return
        }

        let message = command.message

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.connectionStatusText = "Send failed"
                    _ = error
                }
            }
        } else {
            do {
                try session.updateApplicationContext(message)
                refreshStatus(for: session)
            } catch {
                connectionStatusText = "Queued"
            }
        }
        #endif
    }

    #if canImport(WatchConnectivity)
    private func refreshStatus(for session: WCSession) {
        isReachable = session.isReachable

        #if os(iOS)
        if session.activationState != .activated {
            connectionStatusText = "Activating…"
        } else if session.isReachable {
            connectionStatusText = "Apple Watch connected"
        } else if session.isPaired && session.isWatchAppInstalled {
            connectionStatusText = "Watch app ready"
        } else if session.isPaired {
            connectionStatusText = "Install the watch app"
        } else {
            connectionStatusText = "No paired Apple Watch"
        }
        #elseif os(watchOS)
        if session.activationState != .activated {
            connectionStatusText = "Activating…"
        } else if session.isReachable {
            connectionStatusText = "Connected"
        } else {
            connectionStatusText = "Tap Connect"
        }
        #else
        connectionStatusText = session.isReachable ? "Connected" : "Not connected"
        #endif
    }

    private func handleIncomingMessage(_ message: [String: Any], session: WCSession) {
        refreshStatus(for: session)

        // Ignore non-command pings used solely to establish reachability.
        if let type = message["type"] as? String, type == "ping" {
            return
        }

        guard let command = WatchCommand(message: message) else {
            return
        }

        lastReceivedCommand = command
        onCommand?(command)
    }
    #endif
}

#if canImport(WatchConnectivity)
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if error != nil {
                self.connectionStatusText = "Activation failed"
            }
            self.refreshStatus(for: session)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshStatus(for: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleIncomingMessage(message, session: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleIncomingMessage(applicationContext, session: session)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.refreshStatus(for: session)
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
