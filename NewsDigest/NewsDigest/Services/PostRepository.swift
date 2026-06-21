import Foundation

/// Абстракция источника постов. UI и ViewModel зависят только от протокола.
protocol PostRepository {
    /// Загрузить посты (новые сверху).
    func fetchPosts(limit: Int) async throws -> [Post]

    /// Сигнал о появлении новых постов в реальном времени. Значение не важно —
    /// получив сигнал, ViewModel делает полный refresh (надёжнее, чем доверять
    /// декоду отдельной realtime-записи).
    func liveInserts() -> AsyncStream<Void>
}
