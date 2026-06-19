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

/// Лёгкое «вдавливание» при нажатии — для карточек-кнопок.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
