import Foundation

/// Абстракция источника постов. UI и ViewModel зависят только от протокола.
protocol PostRepository {
    /// Загрузить посты (новые сверху).
    func fetchPosts(limit: Int) async throws -> [Post]

    /// Поток новых постов в реальном времени.
    func liveInserts() -> AsyncStream<Post>
}
