import Foundation

/// Абстракция источника данных. UI и ViewModel зависят только от протокола,
/// поэтому Supabase можно заменить без изменений в остальном коде.
protocol DigestRepository {
    /// Загрузить ленту дайджестов (новые сверху).
    func fetchDigests(limit: Int) async throws -> [Digest]

    /// Поток новых вставок в реальном времени.
    /// Каждый элемент — только что добавленный дайджест.
    func liveInserts() -> AsyncStream<Digest>
}
