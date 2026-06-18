import SwiftUI

/// Карточка одного дайджеста. Вся поверхность кликабельна (разворачивает
/// полный текст). Заголовок — жирный, excerpt — вторичным цветом в 2 строки.
struct DigestCardView: View {
    let digest: Digest
    @State private var isExpanded = false

    private var dateText: String {
        DigestDateFormatter.string(for: digest.publishedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Text(digest.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : 3)

            if isExpanded {
                if !digest.excerpt.isEmpty {
                    Text(digest.excerpt)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                sources
            } else if !digest.excerpt.isEmpty {
                Text(digest.excerpt)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            Text(dateText)
                .font(.system(size: 15, weight: .semibold))

            Spacer(minLength: 8)

            Text(digest.type.label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            ShareLink(item: digest.shareText(dateText: dateText)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15))
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
