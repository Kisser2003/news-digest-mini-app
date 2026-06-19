import SwiftUI

extension EditionType {
    /// Акцентный цвет типа выпуска: тёплый для утра, холодный для вечера.
    var tint: Color {
        switch self {
        case .morning: return Color(hex: "FF9F0A")  // тёплый янтарь
        case .evening: return Color(hex: "5E5CE6")  // индиго
        }
    }
}

/// Фон с мягким свечением сверху. Тонко тонируется акцентом экрана.
struct HeroBackground: View {
    var tint: Color = .accentColor

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [tint.opacity(0.22), tint.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }
}

/// Лёгкое «вдавливание» при нажатии — для карточек-кнопок.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
