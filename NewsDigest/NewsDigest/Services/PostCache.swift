import Foundation

/// Персистентный кэш постов на диске. Позволяет показать ленту мгновенно при
/// запуске (из кэша), пока идёт свежий сетевой запрос — без скелетона каждый раз.
enum PostCache {
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("posts.cache.json")
    }()

    static func save(_ posts: [Post]) {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        let url = fileURL
        // Запись на диск — в фоне, чтобы не блокировать главный поток на refresh.
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load() -> [Post] {
        guard let data = try? Data(contentsOf: fileURL),
              let posts = try? JSONDecoder().decode([Post].self, from: data) else { return [] }
        return posts
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static var sizeBytes: Int {
        (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
}

/// Единая точка управления всеми кэшами (картинки + видео-превью + посты).
@MainActor
enum CacheManager {
    /// Суммарный размер кэша в байтах (диск картинок + файл постов).
    static func totalSizeBytes() async -> Int {
        await ImageLoader.shared.diskUsageBytes() + PostCache.sizeBytes
    }

    /// Сбросить всё: декодированные картинки, дисковый URLCache, постеры видео, посты.
    static func clearAll() async {
        await ImageLoader.shared.clearCache()
        await VideoThumbnailLoader.shared.clearCache()
        PostCache.clear()
    }
}
