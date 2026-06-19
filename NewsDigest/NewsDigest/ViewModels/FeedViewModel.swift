import Foundation
import Observation

/// Состояние ленты: посты, сгруппированные в выпуски (утро/вечер) → по каналам.
@MainActor
@Observable
final class FeedViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var editions: [Edition] = []
    private(set) var state: LoadState = .idle

    private let repository: PostRepository
    private var realtimeTask: Task<Void, Never>?

    /// Порядок каналов в выпуске.
    private static let channelOrder = ["ateobreaking", "vcnews", "easy_qa_ru", "media_apple"]

    init(repository: PostRepository = SupabasePostRepository()) {
        self.repository = repository
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            editions = Self.group(try await repository.fetchPosts(limit: 300))
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        do {
            editions = Self.group(try await repository.fetchPosts(limit: 300))
            state = .loaded
        } catch {
            if editions.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    func startListening() {
        guard realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            guard let stream = self?.repository.liveInserts() else { return }
            for await _ in stream {
                await self?.refresh()
            }
        }
    }

    func stopListening() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    // MARK: Группировка

    static func group(_ posts: [Post]) -> [Edition] {
        let byEdition = Dictionary(grouping: posts) { "\($0.editionDate)-\($0.edition.rawValue)" }

        var result: [Edition] = []
        for (key, group) in byEdition {
            guard let first = group.first else { continue }

            let byChannel = Dictionary(grouping: group) { $0.channel }
            var channelGroups = byChannel.map { channel, posts in
                ChannelGroup(
                    id: channel,
                    channel: channel,
                    posts: posts.sorted { $0.publishedAt > $1.publishedAt }
                )
            }
            channelGroups.sort {
                let a = channelOrder.firstIndex(of: $0.channel.lowercased()) ?? .max
                let b = channelOrder.firstIndex(of: $1.channel.lowercased()) ?? .max
                return a < b
            }

            let latest = group.map(\.publishedAt).max() ?? first.publishedAt
            result.append(
                Edition(id: key, date: first.editionDate, type: first.edition,
                        publishedAt: latest, channels: channelGroups)
            )
        }
        return result.sorted { $0.publishedAt > $1.publishedAt }
    }
}
