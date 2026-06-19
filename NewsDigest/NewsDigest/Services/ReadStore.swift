import Foundation
import Observation

/// Локальное хранилище прочитанных постов (UserDefaults). Пост «новый», пока
/// его id не попал в `seen`. Помечается прочитанным при открытии выпуска.
@MainActor
@Observable
final class ReadStore {
    private(set) var seen: Set<UUID> = []
    private let key = "seenPostIDs.v1"

    init() {
        if let arr = UserDefaults.standard.array(forKey: key) as? [String] {
            seen = Set(arr.compactMap { UUID(uuidString: $0) })
        }
    }

    func isSeen(_ id: UUID) -> Bool { seen.contains(id) }

    func unreadCount(_ posts: [Post]) -> Int {
        posts.reduce(0) { $0 + (seen.contains($1.id) ? 0 : 1) }
    }

    func markSeen(_ posts: [Post]) {
        var changed = false
        for p in posts where !seen.contains(p.id) {
            seen.insert(p.id)
            changed = true
        }
        if changed {
            UserDefaults.standard.set(seen.map(\.uuidString), forKey: key)
        }
    }
}
