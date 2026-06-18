import SwiftUI

/// Главный экран — лента дайджестов.
struct FeedView: View {
    @State private var viewModel = FeedViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Дайджесты")
                .navigationBarTitleDisplayMode(.large)
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
        case .idle, .loading where viewModel.digests.isEmpty:
            SkeletonFeed()

        case .failed(let message) where viewModel.digests.isEmpty:
            ErrorState(message: message) {
                Task { await viewModel.load() }
            }

        default:
            feedList
        }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.digests.isEmpty {
                    EmptyState()
                        .padding(.top, 80)
                } else {
                    ForEach(viewModel.digests) { digest in
                        DigestCardView(digest: digest)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await viewModel.refresh() }
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
                        .frame(height: 120)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Дайджестов пока нет")
                .font(.headline)
            Text("Новые выпуски появятся здесь автоматически")
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
            Text("Не удалось загрузить")
                .font(.headline)
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
