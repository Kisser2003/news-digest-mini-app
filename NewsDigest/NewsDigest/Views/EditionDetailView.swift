import SwiftUI

/// Экран одного выпуска: посты, сгруппированные по каналам.
struct EditionDetailView: View {
    let edition: Edition
    @Environment(ReadStore.self) private var readStore
    @State private var newIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(edition.channels) { group in
                    ChannelSection(group: group, newIDs: newIDs)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(HeroBackground(tint: edition.type.tint))
        .navigationTitle(edition.type.label)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Запоминаем, что было новым на момент открытия, затем помечаем прочитанным.
            newIDs = Set(edition.allPosts.filter { !readStore.isSeen($0.id) }.map(\.id))
            readStore.markSeen(edition.allPosts)
        }
    }
}

/// Секция одного канала: заголовок + посты.
private struct ChannelSection: View {
    let group: ChannelGroup
    let newIDs: Set<UUID>

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
                PostCard(post: post, isNew: newIDs.contains(post.id))
            }
        }
    }
}
