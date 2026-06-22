import SwiftUI
import Observation

/// Режим оформления.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "Система"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Акцентный цвет приложения.
enum AccentTheme: String, CaseIterable, Identifiable {
    case blue, indigo, teal, purple, pink, orange, graphite
    var id: String { rawValue }
    var label: String {
        switch self {
        case .blue: return "Синий"
        case .indigo: return "Индиго"
        case .teal: return "Бирюза"
        case .purple: return "Фиолет"
        case .pink: return "Розовый"
        case .orange: return "Оранж"
        case .graphite: return "Графит"
        }
    }
    var color: Color {
        switch self {
        case .blue: return Color(hex: "0A84FF")
        case .indigo: return Color(hex: "5E5CE6")
        case .teal: return Color(hex: "30B0C7")
        case .purple: return Color(hex: "BF5AF2")
        case .pink: return Color(hex: "FF375F")
        case .orange: return Color(hex: "FF9F0A")
        case .graphite: return Color(hex: "8E8E93")
        }
    }
}

/// Размер текста постов (множитель к базовым кеглям).
enum TextSize: String, CaseIterable, Identifiable {
    case compact, normal, large, xlarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .compact: return "S"
        case .normal:  return "M"
        case .large:   return "L"
        case .xlarge:  return "XL"
        }
    }
    var scale: CGFloat {
        switch self {
        case .compact: return 0.9
        case .normal:  return 1.0
        case .large:   return 1.15
        case .xlarge:  return 1.3
        }
    }
}

/// Хранилище настроек оформления (UserDefaults).
@MainActor
@Observable
final class ThemeStore {
    var appearance: AppearanceMode { didSet { save() } }
    var accent: AccentTheme { didSet { save() } }
    var textSize: TextSize { didSet { save() } }

    init() {
        let d = UserDefaults.standard
        appearance = AppearanceMode(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        accent = AccentTheme(rawValue: d.string(forKey: "accent") ?? "") ?? .blue
        textSize = TextSize(rawValue: d.string(forKey: "textSize") ?? "") ?? .normal
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(appearance.rawValue, forKey: "appearance")
        d.set(accent.rawValue, forKey: "accent")
        d.set(textSize.rawValue, forKey: "textSize")
    }
}

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
