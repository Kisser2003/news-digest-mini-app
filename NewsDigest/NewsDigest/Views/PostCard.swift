import SwiftUI

/// Карточка одного поста: (опц. канал) + текст + картинка + переход в Telegram.
struct PostCard: View {
    let post: Post
    var showChannel: Bool = false
    var isNew: Bool = false

    @Environment(\.openURL) private var openURL
    @State private var zoom: ZoomImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isNew {
                HStack(spacing: 5) {
                    Circle().fill(Color.accentColor).frame(width: 7, height: 7)
                    Text("Новое")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            if showChannel {
                HStack(spacing: 8) {
                    Text(post.info.short)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(post.info.color, in: .circle)
                    Text(post.info.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

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
                .contentShape(.rect)
                .onTapGesture {
                    Haptics.impact(.light)
                    zoom = ZoomImage(url: url)
                }
            }

            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.system(size: 11))
                    Text(DigestDateFormatter.timeOnly(for: post.publishedAt))
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("Открыть").font(.system(size: 13, weight: .medium))
                    Image(systemName: "arrow.up.forward").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .contentShape(.rect)
        .onTapGesture {
            guard let url = post.telegramURL else { return }
            Haptics.impact(.medium)
            openURL(url)
        }
        .fullScreenCover(item: $zoom) { item in
            ImageViewer(url: item.url)
        }
    }
}

private extension Post {
    var info: ChannelInfo { ChannelInfo.of(channel) }
}
