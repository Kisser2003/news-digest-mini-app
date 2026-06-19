import SwiftUI

/// Метаданные канала для UI: отображаемое имя, короткий бейдж, цвет аватарки.
struct ChannelInfo {
    let displayName: String
    let short: String
    let color: Color

    static func of(_ channel: String) -> ChannelInfo {
        switch channel.lowercased() {
        case "ateobreaking":
            return .init(displayName: "Ateo Breaking", short: "At", color: Color(hex: "E0564F"))
        case "vcnews":
            return .init(displayName: "vc.ru", short: "VC", color: Color(hex: "3D8BDB"))
        case "easy_qa_ru":
            return .init(displayName: "easy QA", short: "QA", color: Color(hex: "1A9E8F"))
        case "media_apple":
            return .init(displayName: "Apple Media", short: "Ap", color: Color(hex: "8E8E93"))
        default:
            return .init(displayName: channel,
                         short: String(channel.prefix(2)).uppercased(),
                         color: Color(hex: "8E8E93"))
        }
    }
}

extension Color {
    /// Цвет из hex-строки вида "RRGGBB".
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
