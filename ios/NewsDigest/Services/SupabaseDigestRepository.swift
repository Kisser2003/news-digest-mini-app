import Foundation
import Supabase

/// Реализация `DigestRepository` поверх Supabase:
/// чтение — через PostgREST, живые обновления — через Realtime.
struct SupabaseDigestRepository: DigestRepository {
    private let client: SupabaseClient
    private let table = "digests"

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    // MARK: Fetch

    func fetchDigests(limit: Int = 50) async throws -> [Digest] {
        try await client
            .from(table)
            .select()
            .order("published_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: Realtime

    func liveInserts() -> AsyncStream<Digest> {
        AsyncStream { continuation in
            let task = Task {
                let channel = client.realtimeV2.channel("public:\(table)")

                let inserts = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: table
                )

                await channel.subscribe()

                for await insert in inserts {
                    if let digest = try? insert.decodeRecord(
                        as: Digest.self,
                        decoder: SupabaseConfig.jsonDecoder
                    ) {
                        continuation.yield(digest)
                    }
                }

                await channel.unsubscribe()
                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
