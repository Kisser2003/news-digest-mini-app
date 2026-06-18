import SwiftUI

/// Карточка одного дайджеста. Вся поверхность кликабельна (разворачивает
/// полный текст). В свёрнутом виде — превью 3 строки; в развёрнутом — полный
/// текст с сохранением структуры (переносы блоков), крупным читаемым шрифтом.
struct DigestCardView: View {
    let digest: Digest
    @State private var isExpanded = false

    private var dateText: String {
        DigestDateFormatter.string(for: digest.publishedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isExpanded {
                Text(digest.content)
                    .font(.system(size: 16))
                    .lineSpacing(5)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                sources
            } else {
                Text(digest.content)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            chevron
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() }
        }
    }

    // MARK: Subviews

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: digest.type.icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            Text(dateText)
                .font(.system(size: 16, weight: .semibold))

            Spacer(minLength: 8)

            Text(digest.type.label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            ShareLink(item: digest.shareText(dateText: dateText)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var sources: some View {
        Text("@Ateobreaking · @vcnews · @easy_qa_ru · @media_apple")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .padding(.top, 4)
    }

    private var chevron: some View {
        HStack {
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
            Spacer()
        }
    }
}
