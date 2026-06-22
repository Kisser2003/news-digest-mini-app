import SwiftUI

/// Главный экран — живая лента, сгруппированная по каналам (новое сверху).
struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showSettings = false
    /// Меняется при возврате из фона — перезапускает realtime-подписку.
    @State private var listenToken = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeStore.self) private var theme
    @Environment(ReadStore.self) private var readStore
    @Environment(ChannelStore.self) private var channelStore

    var body: some View {
        NavigationStack {
            content
                .background(HeroBackground(tint: theme.accent.color))
                .navigationTitle("Новости")
                .navigationDestination(for: ChannelRoute.self) { route in
                    ChannelScreen(channel: route.channel,
                                  posts: viewModel.posts(for: route.channel))
                }
                .toolbar { toolbarContent }
                .searchable(text: $viewModel.searchText, prompt: "Поиск по постам")
                .sheet(isPresented: $showSettings) {
                    SettingsView(allPosts: viewModel.allPosts)
                }
        }
        .task {
            await channelStore.load()
            viewModel.setChannels(channelStore.slugs)
            await viewModel.load()
            readStore.seedIfNeeded(viewModel.allPosts)
            readStore.prune(to: Set(viewModel.allPosts.map(\.id)))
        }
        .onChange(of: channelStore.slugs) {
            viewModel.setChannels(channelStore.slugs)
        }
        // Отдельная задача под realtime: токен меняется при возврате из фона →
        // подписка пересоздаётся (старый websocket мог отвалиться, пока свёрнуто).
        .task(id: listenToken) {
            await viewModel.listenForUpdates()
        }
        .onChange(of: viewModel.allPosts.count) {
            readStore.seedIfNeeded(viewModel.allPosts)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                listenToken += 1
                Task { await viewModel.refresh() }   // догнать пропущенное за время в фоне
            case .background:
                BackgroundRefresh.schedule()    // запланировать фоновую проверку новых постов
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            SkeletonFeed()
        case .loading where viewModel.allPosts.isEmpty:
            SkeletonFeed()
        case .failed(let message) where viewModel.allPosts.isEmpty:
            ErrorState(message: message) { Task { await viewModel.load() } }
        default:
            if viewModel.isSearching { searchResultsList } else { feed }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                Haptics.selection()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(viewModel.allChannels, id: \.self) { channel in
                    let info = ChannelInfo.of(channel)
                    Toggle(isOn: Binding(
                        get: { !viewModel.disabledChannels.contains(channel.lowercased()) },
                        set: { _ in
                            Haptics.selection()
                            viewModel.toggleChannel(channel)
                        }
                    )) {
                        Text(info.displayName)
                    }
                }
            } label: {
                Image(systemName: viewModel.disabledChannels.isEmpty
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    @ViewBuilder
    private var searchResultsList: some View {
        if viewModel.searchResults.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            List {
                ForEach(viewModel.searchResults) { post in
                    PostCard(post: post, showChannel: true)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if viewModel.sections.isEmpty {
                    EmptyState().padding(.top, 80)
                } else {
                    ForEach(viewModel.sections) { section in
                        ChannelRow(group: section)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.smooth, value: viewModel.allChannels)
        }
        .refreshable {
            await viewModel.refresh()
            Haptics.success()
        }
    }
}

/// Строка канала на главном экране: аватар, название, бейдж непрочитанного,
/// превью последнего поста. Тап — провалиться в канал (вся его лента).
private struct ChannelRow: View {
    let group: ChannelGroup
    @Environment(ReadStore.self) private var readStore

    private var unread: Int {
        group.posts.reduce(0) { $0 + (readStore.isSeen($1.id) ? 0 : 1) }
    }
    private var latest: Post? { group.posts.first }

    var body: some View {
        NavigationLink(value: ChannelRoute(channel: group.channel)) {
            HStack(spacing: 12) {
                ChannelAvatar(channel: group.channel, info: group.info)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(group.info.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                        if unread > 0 {
                            Text("\(unread)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 20)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(group.info.color, in: .capsule)
                        }
                        Spacer(minLength: 4)
                        if let latest {
                            Text(DigestDateFormatter.timeOnly(for: latest.publishedAt))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(previewText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var previewText: String {
        guard let latest else { return "Постов пока нет" }
        if latest.hasText { return latest.text ?? "" }
        switch latest.media {
        case .video: return "🎬 Видео"
        case .image: return "🖼 Фото"
        case .none:  return "—"
        }
    }
}

/// Аватарка канала из Telegram (через прокси `tg.i-c-a.su/icon/<slug>/icon.jpg`).
/// Пока грузится / если фото нет — цветной бейдж с буквами (как раньше).
private struct ChannelAvatar: View {
    let channel: String
    let info: ChannelInfo

    private var url: URL? {
        URL(string: "https://tg.i-c-a.su/icon/\(channel)/icon.jpg")
    }

    var body: some View {
        Group {
            if let url {
                CachedImage(url: url, targetWidth: 44) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        badge
                    }
                }
            } else {
                badge
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(.circle)
    }

    private var badge: some View {
        ZStack {
            info.color
            Text(info.short)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Вспомогательные состояния

private struct SkeletonFeed: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(height: 96)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(16)
        }
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Новостей пока нет")
                .font(.headline)
            Text("Появятся, как только выйдут в каналах")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

private struct ErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Не удалось загрузить").font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Повторить", action: retry)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(32)
    }
}
