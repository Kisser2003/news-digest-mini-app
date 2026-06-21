import SwiftUI

/// Все посты одного канала по всем выпускам.
struct ChannelScreen: View {
    let channel: String
    let posts: [Post]

    @Environment(ReadStore.self) private var readStore
    private var info: ChannelInfo { ChannelInfo.of(channel) }

    var body: some View {
        // List (UIKit-backed) вместо ScrollView+LazyVStack: корректно держит
        // высоты ячеек и content-offset — нет «прыжков» прокрутки на длинной
        // ленте с разновысокими карточками.
        List {
            ForEach(posts) { post in
                PostCard(post: post)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(HeroBackground(tint: info.color))
        .navigationTitle(info.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { readStore.markSeen(posts) }
    }
}
