import SwiftUI

/// URL с Identifiable-обёрткой для fullScreenCover(item:).
struct ZoomImage: Identifiable {
    let id = UUID()
    let url: URL
}

/// Полноэкранный просмотр картинки: пинч-зум, двойной тап, крестик.
struct ImageViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(magnify)
                        .onTapGesture(count: 2) { toggleZoom() }
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.6))
                case .empty:
                    ProgressView().tint(.white)
                @unknown default:
                    EmptyView()
                }
            }

            VStack {
                HStack {
                    Spacer()
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
                Spacer()
            }
        }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in scale = max(1, min(lastScale * value, 5)) }
            .onEnded { _ in lastScale = scale }
    }

    private func toggleZoom() {
        Haptics.impact(.light)
        withAnimation(.snappy) {
            scale = scale > 1 ? 1 : 2.5
            lastScale = scale
        }
    }
}
