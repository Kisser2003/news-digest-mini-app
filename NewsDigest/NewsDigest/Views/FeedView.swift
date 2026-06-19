import SwiftUI

/// Главный экран — лента выпусков (утро/вечер).
struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showSettings = false
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        NavigationStack {
            content
                .background(HeroBackground(tint: theme.accent.color))
                .navigationTitle("Дайджесты")
                .navigationDestination(for: Edition.self) { edition in
                    EditionDetailView(edition: edition)
                }
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
            viewModel.startListening()
        }
        .onDisappear { viewModel.stopListening() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading where viewModel.allPosts.isEmpty:
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
        }    }

    private var feed: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.editions.isEmpty {
                    EmptyState().padding(.top, 80)
                } else {
                    ForEach(viewModel.editions) { edition in
                        NavigationLink(value: edition) {
                            EditionCardView(edition: edition)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.smooth, value: viewModel.editions)
        }        .refreshable {
            await viewModel.refresh()
            Haptics.success()
        }
    }
}

/// Карточка выпуска в ленте.
struct EditionCardView: View {
    let edition: Edition
    @Environment(ReadStore.self) private var readStore

    private var unread: Int { readStore.unreadCount(edition.allPosts) }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(edition.type.tint.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: edition.type.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(edition.type.tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(DigestDateFormatter.string(for: edition.publishedAt))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(edition.type.label) · \(edition.totalPosts) постов")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(edition.type.tint, in: .capsule)
                }
            }

            HStack(spacing: 8) {
                avatarRow
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    private var avatarRow: some View {
        HStack(spacing: -6) {
            ForEach(edition.channels) { group in
                Text(group.info.short)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(group.info.color, in: .circle)
                    .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2))
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
        }    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Выпусков пока нет")
                .font(.headline)
            Text("Новые появятся утром и вечером автоматически")
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
