import Foundation
import Supabase

/// Реализация `PostRepository` поверх Supabase: чтение через PostgREST,
/// живые обновления через Realtime.
struct SupabasePostRepository: PostRepository {
    private let client: SupabaseClient
    private let table = "posts"

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    func fetchPosts(limit: Int = 300) async throws -> [Post] {
        try await client
            .from(table)
            .select()
            .order("published_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func liveInserts() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                let channel = client.realtimeV2.channel("public:\(table)")
                let inserts = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: table
                )
                do {
                    try await channel.subscribeWithError()
                } catch {
                    continuation.finish()
                    return
                }
                // Значение не декодируем — нужен только сигнал «появились новые».
                for await _ in inserts {
                    continuation.yield(())
                }
                await channel.unsubscribe()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
