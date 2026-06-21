import SwiftUI
import AVKit

/// URL видео с Identifiable-обёрткой для fullScreenCover(item:).
struct PlayingVideo: Identifiable {
    let id = UUID()
    let url: URL
}

/// Полноэкранный плеер видео из поста. Стримит по запросу (тап по постеру).
struct VideoPlayerScreen: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            VideoPlayer(player: player)
                .ignoresSafeArea()

            Button {
                Haptics.selection()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding()
            }
        }
        .onAppear { player.play() }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }
}
