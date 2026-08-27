import Foundation

enum WatchCommandType: String, Codable {
    case startTest
    case responseCorrect
    case responseWrong
    case repeatItem
    case nextItem
    case endTest

    // Peer device selection (Watch ↔ iPhone)
    /// iPhone → Watch: payload["peers"] = comma-separated MPC peer display names
    case availablePeers
    /// Watch → iPhone: payload["name"] = chosen peer display name
    case selectPeer
    /// iPhone → Watch: payload["name"] = the peer that just connected
    case peerConnected
    /// iPhone → Watch: full MPC snapshot. payload["statusText"] = human-readable status,
    /// payload["device"] = connected device name or "" if not connected.
    /// Sent every time Watch becomes reachable so Watch always has fresh state.
    case peerStatus
}

struct WatchCommand: Equatable {
    static let typeKey = "type"

    let type: WatchCommandType
    let payload: [String: String]

    init(type: WatchCommandType, payload: [String: String] = [:]) {
        self.type = type
        self.payload = payload
    }

    init?(message: [String: Any]) {
        guard
            let rawType = message[Self.typeKey] as? String,
            let type = WatchCommandType(rawValue: rawType)
        else {
            return nil
        }

        var payload = message.compactMapValues { value in
            value as? String
        }
        payload.removeValue(forKey: Self.typeKey)

        self.init(type: type, payload: payload)
    }

    var message: [String: Any] {
        var message = payload
        message[Self.typeKey] = type.rawValue
        return message
    }
}
