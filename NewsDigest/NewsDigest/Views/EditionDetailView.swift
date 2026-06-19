import SwiftUI

/// Экран одного выпуска: посты, сгруппированные по каналам.
struct EditionDetailView: View {
    let edition: Edition

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(edition.channels) { group in
                    ChannelSection(group: group)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(edition.type.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Секция одного канала: заголовок + посты.
private struct ChannelSection: View {
    let group: ChannelGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(group.info.short)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(group.info.color, in: .circle)
                Text(group.info.displayName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(group.posts.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            ForEach(group.posts) { post in
                PostView(post: post)
            }
        }
    }
}

/// Одна карточка поста: текст + картинка + переход в Telegram.
private struct PostView: View {
    let post: Post
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if post.hasText {
                Text(post.text ?? "")
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let url = post.imageRemoteURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        Rectangle().fill(Color(.tertiarySystemGroupedBackground))
                            .overlay(ProgressView())
                    case .failure:
                        Rectangle().fill(Color(.tertiarySystemGroupedBackground))
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 260)
                .clipShape(.rect(cornerRadius: 12))
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 12))
                Text("Открыть в Telegram")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Color.accentColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .contentShape(.rect)
        .onTapGesture {
            if let url = post.telegramURL { openURL(url) }
        }
    }
}
