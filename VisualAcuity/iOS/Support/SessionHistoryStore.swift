import Foundation

/// Persists completed `StoredSession`s locally in UserDefaults so the user can
/// review past results in History. Small, dependency-free on purpose — this
/// is a prototype and a full database is out of scope.
@MainActor
final class SessionHistoryStore {
    static let shared = SessionHistoryStore()

    private static let storageKey = "VisualAcuity.sessionHistory.v1"
    private let maxRetained = 200

    private init() {}

    func load() -> [StoredSession] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return [] }

        do {
            let decoded = try JSONDecoder().decode([StoredSession].self, from: data)
            return decoded.sorted { $0.date > $1.date }
        } catch {
            return []
        }
    }

    func save(_ session: StoredSession) {
        var sessions = load()
        sessions.insert(session, at: 0)
        if sessions.count > maxRetained {
            sessions = Array(sessions.prefix(maxRetained))
        }
        persist(sessions)
    }

    func delete(id: UUID) {
        var sessions = load()
        sessions.removeAll { $0.id == id }
        persist(sessions)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    private func persist(_ sessions: [StoredSession]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // Silently drop — not worth crashing a prototype.
        }
    }
}
