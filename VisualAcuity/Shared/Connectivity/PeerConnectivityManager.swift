import Foundation
import Combine

#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class PeerConnectivityManager: NSObject, ObservableObject {
    private static let rememberedDisplayPeerNameKey = "PeerConnectivityManager.rememberedDisplayPeerName"

    enum Role: Equatable {
        case inactive
        case controller
        case display
    }

    // MARK: – Published state

    @Published private(set) var role: Role = .inactive
    @Published private(set) var isConnected = false
    @Published private(set) var connectionStatusText = "Peer mode inactive"

    /// Human-readable names of peers found by the browser but not yet connected.
    /// Populated only when role == .controller. Always available without importing MPC.
    @Published private(set) var discoveredPeerNames: [String] = []

    /// Display name of the currently connected peer, or nil when not connected.
    @Published private(set) var connectedPeerDisplayName: String?

    #if canImport(MultipeerConnectivity)
    /// The raw MCPeerID objects backing discoveredPeerNames.
    @Published private(set) var discoveredPeers: [MCPeerID] = []
    #endif

    var onMessage: ((PeerSessionMessage) -> Void)?

    var displayWaitingStatusText: String {
        if role == .display && isConnected {
            return "Connected. Waiting for the controller to start the test."
        }
        return connectionStatusText
    }

    #if canImport(MultipeerConnectivity)
    private let serviceType = "visacuity-mvp"
    nonisolated(unsafe) private let localPeerID: MCPeerID
    nonisolated(unsafe) private let session: MCSession

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var invitedPeerIDs = Set<MCPeerID>()
    private var activePeerID: MCPeerID?
    private var pendingIncomingInvitationPeerID: MCPeerID?
    private var autoConnectTask: Task<Void, Never>?
    #endif

    private var rememberedDisplayPeerName: String? {
        get { UserDefaults.standard.string(forKey: Self.rememberedDisplayPeerNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.rememberedDisplayPeerNameKey) }
    }

    override init() {
        #if canImport(MultipeerConnectivity)
        let localPeerID = MCPeerID(displayName: Self.defaultPeerName)
        let session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.localPeerID = localPeerID
        self.session = session
        #endif

        super.init()

        #if canImport(MultipeerConnectivity)
        self.session.delegate = self
        #endif
    }

    // MARK: – Public API

    func configure(role: Role) {
        #if canImport(MultipeerConnectivity)
        let alreadyCorrect: Bool
        switch role {
        case .inactive:   alreadyCorrect = self.role == .inactive && advertiser == nil && browser == nil
        case .controller: alreadyCorrect = self.role == .controller && browser != nil
        case .display:    alreadyCorrect = self.role == .display   && advertiser != nil
        }

        if alreadyCorrect {
            refreshConnectionStatus()
            return
        }

        self.role = role
        stop()
        isConnected = false

        switch role {
        case .inactive:
            connectionStatusText = "Peer mode inactive"
        case .controller:
            startBrowsing()
            connectionStatusText = "Searching for display devices…"
        case .display:
            startAdvertising()
            connectionStatusText = "Waiting for controller…"
        }
        #else
        self.role = role
        isConnected = false
        connectionStatusText = "Multipeer Connectivity unavailable"
        #endif
    }

    func send(_ message: PeerSessionMessage) {
        #if canImport(MultipeerConnectivity)
        let targetPeers = connectedTargetPeersForSend()
        guard !targetPeers.isEmpty else {
            connectionStatusText = role == .controller ? "Waiting for display device…" : "Waiting for controller…"
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: targetPeers, with: .reliable)
        } catch {
            connectionStatusText = "Peer send failed: \(error.localizedDescription)"
        }
        #endif
    }

    /// Invite a specific discovered peer by display name. Safe to call without
    /// importing MultipeerConnectivity — the lookup and invite happen internally.
    func connect(toPeerNamed name: String) {
        #if canImport(MultipeerConnectivity)
        guard let peer = discoveredPeers.first(where: { $0.displayName == name }) else { return }
        connect(to: peer)
        #endif
    }

    func refreshConnection() {
        #if canImport(MultipeerConnectivity)
        let currentRole = role
        guard currentRole != .inactive else {
            refreshConnectionStatus()
            return
        }

        stop()

        switch currentRole {
        case .inactive:
            connectionStatusText = "Peer mode inactive"
        case .controller:
            startBrowsing()
            connectionStatusText = "Searching for display devices…"
        case .display:
            startAdvertising()
            connectionStatusText = "Waiting for controller…"
        }
        #else
        configure(role: role)
        #endif
    }

    #if canImport(MultipeerConnectivity)
    /// Invite a specific discovered MCPeerID to connect.
    func connect(to peerID: MCPeerID) {
        guard role == .controller,
              !isConnected,
              session.connectedPeers.isEmpty,
              invitedPeerIDs.isEmpty,
              !invitedPeerIDs.contains(peerID),
              discoveredPeers.contains(peerID),
              let browser else { return }
        autoConnectTask?.cancel()
        autoConnectTask = nil
        invitedPeerIDs.insert(peerID)
        connectionStatusText = "Connecting to \(peerID.displayName)…"
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    #endif

    // MARK: – Private helpers

    #if canImport(MultipeerConnectivity)
    private static var defaultPeerName: String {
        LocalDeviceIdentity.displayName
    }

    private func stop() {
        session.disconnect()
        autoConnectTask?.cancel()
        autoConnectTask = nil

        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil

        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil

        invitedPeerIDs.removeAll()
        activePeerID = nil
        pendingIncomingInvitationPeerID = nil
        discoveredPeers.removeAll()
        discoveredPeerNames.removeAll()
        isConnected = false
        connectedPeerDisplayName = nil
    }

    private func startAdvertising() {
        advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: ["role": "display"],
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    private func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    private func refreshConnectionStatus() {
        if let activePeerID, !session.connectedPeers.contains(activePeerID) {
            self.activePeerID = nil
        }

        if activePeerID == nil {
            activePeerID = session.connectedPeers.first
        }

        isConnected = activePeerID != nil
        connectedPeerDisplayName = activePeerID?.displayName

        if let peerName = connectedPeerDisplayName {
            connectionStatusText = "Connected to \(peerName)"
            return
        }

        switch role {
        case .inactive:
            connectionStatusText = "Peer mode inactive"
        case .controller:
            if discoveredPeerNames.isEmpty {
                connectionStatusText = "Searching for display devices…"
            } else if let preferredPeerName = preferredDisplayPeerName {
                connectionStatusText = "Found your last display, \(preferredPeerName) — connecting automatically"
            } else if discoveredPeerNames.count == 1 {
                connectionStatusText = "Found 1 display device — connecting automatically"
            } else {
                connectionStatusText = "Found \(discoveredPeerNames.count) display devices — choose one below"
            }
        case .display:
            connectionStatusText = "Waiting for controller…"
        }
    }

    private func scheduleAutoConnectIfNeeded() {
        autoConnectTask?.cancel()
        autoConnectTask = nil

        guard role == .controller,
              !isConnected,
              invitedPeerIDs.isEmpty,
              let peer = autoConnectCandidatePeer else {
            return
        }

        autoConnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)

            guard let self,
                  self.role == .controller,
                  !self.isConnected,
                  self.invitedPeerIDs.isEmpty,
                  self.discoveredPeers.contains(peer) else {
                return
            }

            self.connect(to: peer)
        }
    }

    private var autoConnectCandidatePeer: MCPeerID? {
        if let preferredDisplayPeerName,
           let preferredPeer = discoveredPeers.first(where: { $0.displayName == preferredDisplayPeerName }) {
            return preferredPeer
        }

        guard discoveredPeers.count == 1 else { return nil }
        return discoveredPeers.first
    }

    private var preferredDisplayPeerName: String? {
        guard let rememberedDisplayPeerName,
              discoveredPeerNames.contains(rememberedDisplayPeerName) else {
            return nil
        }

        return rememberedDisplayPeerName
    }

    private func handleIncomingData(_ data: Data, from peerID: MCPeerID) {
        if activePeerID == nil {
            activePeerID = peerID
            refreshConnectionStatus()
        }

        if let activePeerID, activePeerID != peerID {
            return
        }

        do {
            let message = try JSONDecoder().decode(PeerSessionMessage.self, from: data)
            onMessage?(message)
        } catch {
            connectionStatusText = "Peer receive failed: \(error.localizedDescription)"
        }
    }

    private func connectedTargetPeersForSend() -> [MCPeerID] {
        if let activePeerID, session.connectedPeers.contains(activePeerID) {
            return [activePeerID]
        }

        guard let firstConnectedPeer = session.connectedPeers.first else {
            return []
        }

        activePeerID = firstConnectedPeer
        refreshConnectionStatus()
        return [firstConnectedPeer]
    }
    #endif
}

#if canImport(MultipeerConnectivity)
extension PeerConnectivityManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            if state == .connected {
                if self.activePeerID == nil {
                    self.activePeerID = peerID
                }

                if self.role == .controller, self.activePeerID == peerID {
                    self.rememberedDisplayPeerName = peerID.displayName
                    // Clear discovered list — only one connection at a time.
                    self.discoveredPeers.removeAll()
                    self.discoveredPeerNames.removeAll()
                }

                self.autoConnectTask?.cancel()
                self.autoConnectTask = nil
                self.pendingIncomingInvitationPeerID = nil
            } else if state == .notConnected {
                self.invitedPeerIDs.remove(peerID)
                if self.activePeerID == peerID {
                    self.activePeerID = nil
                }
                if self.pendingIncomingInvitationPeerID == peerID {
                    self.pendingIncomingInvitationPeerID = nil
                }
            }
            self.refreshConnectionStatus()
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.handleIncomingData(data, from: peerID)
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) { }

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) { }

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) { }
}

extension PeerConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            let shouldAccept = self.role == .display
                && self.activePeerID == nil
                && self.session.connectedPeers.isEmpty
                && self.pendingIncomingInvitationPeerID == nil

            if shouldAccept {
                self.pendingIncomingInvitationPeerID = peerID
                self.connectionStatusText = "Connecting to \(peerID.displayName)…"
                invitationHandler(true, self.session)
            } else {
                invitationHandler(false, nil)
            }
        }
    }

    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        Task { @MainActor in
            self.connectionStatusText = "Advertising failed: \(error.localizedDescription)"
        }
    }
}

extension PeerConnectivityManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            guard info?["role"] == "display" else { return }
            guard !self.isConnected,
                  !self.invitedPeerIDs.contains(peerID),
                  !self.discoveredPeers.contains(peerID) else { return }
            self.discoveredPeers.append(peerID)
            self.discoveredPeerNames = self.discoveredPeers.map(\.displayName)
            self.refreshConnectionStatus()
            self.scheduleAutoConnectIfNeeded()
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0 == peerID }
            self.discoveredPeerNames.removeAll { $0 == peerID.displayName }
            self.invitedPeerIDs.remove(peerID)
            self.refreshConnectionStatus()
            self.scheduleAutoConnectIfNeeded()
        }
    }

    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        Task { @MainActor in
            self.connectionStatusText = "Browsing failed: \(error.localizedDescription)"
        }
    }
}
#endif
