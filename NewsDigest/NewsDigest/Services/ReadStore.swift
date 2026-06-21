import Foundation
import Observation

/// Локальное хранилище прочитанных постов (UserDefaults). Пост «новый», пока
/// его id не попал в `seen`. Помечается прочитанным при открытии выпуска.
@MainActor
@Observable
final class ReadStore {
    private(set) var seen: Set<UUID> = []
    private let key = "seenPostIDs.v1"
    private let seededKey = "didSeedInitialRead.v1"

    init() {
        if let arr = UserDefaults.standard.array(forKey: key) as? [String] {
            seen = Set(arr.compactMap { UUID(uuidString: $0) })
        }
    }

    func isSeen(_ id: UUID) -> Bool { seen.contains(id) }

    /// На самом первом запуске считаем уже существующие посты прочитанными —
    /// иначе вся лента подсветилась бы как «Новое». Возвращает true, если засев
    /// только что произошёл (значит ничего помечать «новым» в этой сессии не надо).
    @discardableResult
    func seedIfNeeded(_ posts: [Post]) -> Bool {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return false }
        guard !posts.isEmpty else { return false }   // ждём, пока появятся посты
        markSeen(posts)
        UserDefaults.standard.set(true, forKey: seededKey)
        return true
    }

    func unreadCount(_ posts: [Post]) -> Int {
        posts.reduce(0) { $0 + (seen.contains($1.id) ? 0 : 1) }
    }

    func markSeen(_ posts: [Post]) {
        var changed = false
        for p in posts where !seen.contains(p.id) {
            seen.insert(p.id)
            changed = true
        }
        if changed { persist() }
    }

    /// Сериализация и запись в UserDefaults — в фоне (на main это фризило при
    /// заходе в канал, где помечается прочитанным сразу много постов).
    private func persist() {
        let snapshot = seen
        let key = self.key
        Task.detached(priority: .utility) {
            UserDefaults.standard.set(snapshot.map(\.uuidString), forKey: key)
        }
    }

    func reset() {
        seen.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
}
