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

    private(set) var allPosts: [Post] = []
    private(set) var state: LoadState = .idle

    /// Фильтры (наблюдаемые — UI реагирует).
    var searchText: String = ""
    var disabledChannels: Set<String> = []   // lowercased-слаги выключенных каналов

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
            allPosts = try await repository.fetchPosts(limit: 300)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        do {
            allPosts = try await repository.fetchPosts(limit: 300)
            state = .loaded
        } catch {
            if allPosts.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    // MARK: Фильтрация и поиск

    /// Каналы, реально присутствующие в данных, в нужном порядке.
    var allChannels: [String] {
        var seen: [String] = []
        for p in allPosts where !seen.contains(p.channel) { seen.append(p.channel) }
        return seen.sorted {
            let a = Self.channelOrder.firstIndex(of: $0.lowercased()) ?? .max
            let b = Self.channelOrder.firstIndex(of: $1.lowercased()) ?? .max
            return a < b
        }
    }

    private var visiblePosts: [Post] {
        allPosts.filter { !disabledChannels.contains($0.channel.lowercased()) }
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Выпуски с учётом фильтра каналов.
    var editions: [Edition] { Self.group(visiblePosts) }

    /// Плоский список постов по поисковому запросу.
    var searchResults: [Post] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return visiblePosts.filter {
            ($0.text ?? "").lowercased().contains(q) ||
            ChannelInfo.of($0.channel).displayName.lowercased().contains(q)
        }
    }

    func toggleChannel(_ channel: String) {
        let slug = channel.lowercased()
        if disabledChannels.contains(slug) { disabledChannels.remove(slug) }
        else { disabledChannels.insert(slug) }
    }

    /// Все посты одного канала (по всем выпускам), новые сверху.
    func posts(for channel: String) -> [Post] {
        allPosts
            .filter { $0.channel.lowercased() == channel.lowercased() }
            .sorted { $0.publishedAt > $1.publishedAt }
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
