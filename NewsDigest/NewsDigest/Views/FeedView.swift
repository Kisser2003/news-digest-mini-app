import SwiftUI

/// Главный экран — живая лента, сгруппированная по каналам (новое сверху).
struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showSettings = false
    /// Снимок «новых» постов на время сессии (не сбрасывается при пометке прочитанным).
    @State private var newIDs: Set<UUID> = []
    /// Развёрнутые секции каналов (слаги). Пусто = всё свёрнуто (по умолчанию).
    @State private var expandedChannels: Set<String> = []
    /// Меняется при возврате из фона — перезапускает realtime-подписку.
    @State private var listenToken = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeStore.self) private var theme
    @Environment(ReadStore.self) private var readStore

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
            await viewModel.load()
            captureNew()
        }
        // Отдельная задача под realtime: токен меняется при возврате из фона →
        // подписка пересоздаётся (старый websocket мог отвалиться, пока свёрнуто).
        .task(id: listenToken) {
            await viewModel.listenForUpdates()
        }
        .onChange(of: viewModel.allPosts.count) { captureNew() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                listenToken += 1
                Task {
                    await viewModel.refresh()   // догнать пропущенное за время в фоне
                    captureNew()
                }
            case .background:
                BackgroundRefresh.schedule()    // запланировать фоновую проверку новых постов
            default:
                break
            }
        }
    }

    private func toggleExpand(_ channel: String) {
        let slug = channel.lowercased()
        Haptics.selection()
        withAnimation(.snappy) {
            if expandedChannels.contains(slug) { expandedChannels.remove(slug) }
            else { expandedChannels.insert(slug) }
        }
    }

    /// Запомнить ещё непрочитанные посты как «новые» для текущей сессии.
    /// На первом запуске вместо этого засеваем «прочитано» — чтобы лента не
    /// подсветилась целиком как новая.
    private func captureNew() {
        if readStore.seedIfNeeded(viewModel.allPosts) { return }
        for post in viewModel.allPosts where !readStore.isSeen(post.id) {
            newIDs.insert(post.id)
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

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.searchResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .padding(.top, 60)
                } else {
                    ForEach(viewModel.searchResults) { post in
                        PostCard(post: post, showChannel: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if viewModel.sections.isEmpty {
                    EmptyState().padding(.top, 80)
                } else {
                    ForEach(viewModel.sections) { section in
                        ChannelFeedSection(
                            group: section,
                            newIDs: newIDs,
                            isExpanded: expandedChannels.contains(section.channel.lowercased()),
                            onToggle: { toggleExpand(section.channel) },
                            onSeen: { readStore.markSeen([$0]) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.smooth, value: viewModel.sections)
        }
        .refreshable {
            await viewModel.refresh()
            captureNew()
            Haptics.success()
        }
    }
}

/// Сворачиваемая секция канала: заголовок-стекло (тап — развернуть/свернуть) +
/// свежие посты + ссылка «показать все». По умолчанию свёрнута.
private struct ChannelFeedSection: View {
    let group: ChannelGroup
    let newIDs: Set<UUID>
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSeen: (Post) -> Void

    /// Сколько постов показывать прямо в ленте (остальное — на экране канала).
    private static let previewLimit = 6

    private var unread: Int { group.posts.lazy.filter { newIDs.contains($0.id) }.count }
    private var visible: [Post] { Array(group.posts.prefix(Self.previewLimit)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Text(group.info.short)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(group.info.color, in: .circle)
                    Text(group.info.displayName)
                        .font(.system(size: 18, weight: .bold))
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
                    Spacer(minLength: 8)
                    Text("\(group.posts.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(visible) { post in
                    PostCard(post: post, isNew: newIDs.contains(post.id))
                        .onAppear { onSeen(post) }
                }

                if group.posts.count > Self.previewLimit {
                    NavigationLink(value: ChannelRoute(channel: group.channel)) {
                        HStack(spacing: 6) {
                            Text("Показать все \(group.posts.count)")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(group.info.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
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
