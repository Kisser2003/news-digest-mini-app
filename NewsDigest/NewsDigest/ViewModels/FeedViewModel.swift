import Foundation
import Observation

/// Состояние живой ленты: посты, сгруппированные по каналам (новые сверху).
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

    /// Секции ленты — по одной на канал, посты внутри новые сверху.
    /// Кешируются (пересчёт только при смене данных/фильтра, не на каждый рендер).
    private(set) var sections: [ChannelGroup] = []
    /// Каналы, присутствующие в данных, в нужном порядке (для тулбара).
    private(set) var allChannels: [String] = []

    /// Фильтры (наблюдаемые — UI реагирует).
    var searchText: String = ""
    var disabledChannels: Set<String> = []   // lowercased-слаги выключенных каналов

    private let repository: PostRepository
    private var refreshDebounce: Task<Void, Never>?

    /// Порядок и состав каналов (из ChannelStore). По умолчанию — дефолтные.
    private var channelOrder: [String] = ChannelStore.defaults

    /// Обновить список каналов (вызывается из FeedView, когда ChannelStore загрузился).
    func setChannels(_ slugs: [String]) {
        guard !slugs.isEmpty else { return }
        channelOrder = slugs
        rebuild()
    }

    init(repository: PostRepository? = nil) {
        self.repository = repository ?? SupabasePostRepository()
    }

    func load() async {
        if case .loading = state { return }
        // Мгновенно показать кэш (если есть) — иначе скелетон до сетевого ответа.
        if allPosts.isEmpty {
            let cached = PostCache.load()
            if cached.isEmpty {
                state = .loading
            } else {
                allPosts = cached
                rebuild()
                state = .loaded
            }
        }
        do {
            allPosts = try await repository.fetchPosts(limit: 300)
            rebuild()
            PostCache.save(allPosts)
            state = .loaded
        } catch {
            // Если есть что показать (кэш) — остаёмся на нём, ошибку не показываем.
            if allPosts.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    func refresh() async {
        do {
            allPosts = try await repository.fetchPosts(limit: 300)
            rebuild()
            PostCache.save(allPosts)
            state = .loaded
        } catch {
            if allPosts.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    // MARK: Фильтрация и поиск

    /// Пересобрать кешированные группировки. Вызывается при смене данных/фильтра.
    private func rebuild() {
        allChannels = channelOrder
        let visible = channelOrder.filter { !disabledChannels.contains($0.lowercased()) }
        sections = Self.sections(for: visible, from: allPosts)
    }

    private var visiblePosts: [Post] {
        allPosts.filter { !disabledChannels.contains($0.channel.lowercased()) }
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
        rebuild()
    }

    /// Все посты одного канала (по всем выпускам), новые сверху.
    func posts(for channel: String) -> [Post] {
        allPosts
            .filter { $0.channel.lowercased() == channel.lowercased() }
            .sorted { $0.publishedAt > $1.publishedAt }
    }

    /// Слушать живые вставки, пока не отменят (вызывается из `.task` —
    /// автоматически завершается при уничтожении экрана, переживает навигацию).
    func listenForUpdates() async {
        for await _ in repository.liveInserts() {
            // Дебаунс: выпуск приходит залпом из десятков вставок — каждая отменяет
            // прошлый отложенный refresh, реальный запрос идёт один раз после затишья.
            refreshDebounce?.cancel()
            refreshDebounce = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    // MARK: Группировка

    /// Секции по каждому каналу из списка (в его порядке). Пустые включаются —
    /// добавленный канал виден сразу, ещё до первого фетча постов бэкендом.
    static func sections(for slugs: [String], from posts: [Post]) -> [ChannelGroup] {
        let byChannel = Dictionary(grouping: posts) { $0.channel.lowercased() }
        return slugs.map { slug in
            let key = slug.lowercased()
            let channelPosts = (byChannel[key] ?? []).sorted { $0.publishedAt > $1.publishedAt }
            return ChannelGroup(id: key, channel: channelPosts.first?.channel ?? slug, posts: channelPosts)
        }
    }
}
