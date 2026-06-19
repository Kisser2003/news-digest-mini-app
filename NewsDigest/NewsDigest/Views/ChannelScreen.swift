import SwiftUI

/// Все посты одного канала по всем выпускам.
struct ChannelScreen: View {
    let channel: String
    let posts: [Post]

    private var info: ChannelInfo { ChannelInfo.of(channel) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(posts) { post in
                    PostCard(post: post)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(HeroBackground(tint: info.color))
        .navigationTitle(info.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
