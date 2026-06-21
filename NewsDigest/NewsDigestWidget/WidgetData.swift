import SwiftUI

/// Лёгкая модель поста для виджета (отдельный таргет — без supabase-swift).
struct WidgetPost: Identifiable, Decodable {
    let channel: String
    let messageID: Int?
    let text: String?
    let publishedAt: Date

    var id: String { "\(channel)-\(messageID ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case channel
        case messageID = "message_id"
        case text
        case publishedAt = "published_at"
    }
}

/// Прямой запрос к Supabase REST (виджет не может ходить через App Groups на
/// бесплатном аккаунте, поэтому тянет данные сам, по публичному ключу).
enum WidgetAPI {
    private static let baseURL = "https://puxvslevqvdbkezyfdjm.supabase.co"
    private static let anonKey = "sb_publishable_vaT7exMgVqouTqJToR8X6g_S3rVYpYS"

    static func fetchLatest(limit: Int) async throws -> [WidgetPost] {
        var comps = URLComponents(string: "\(baseURL)/rest/v1/posts")!
        comps.queryItems = [
            URLQueryItem(name: "select", value: "channel,message_id,text,published_at"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([WidgetPost].self, from: data)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = frac.date(from: raw) ?? plain.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Плохая дата: \(raw)")
        }
        return decoder
    }()
}

/// Имя/цвет канала — зеркало `ChannelInfo` основного приложения (таргеты разные).
struct WidgetChannel {
    let name: String
    let color: Color

    static func of(_ channel: String) -> WidgetChannel {
        switch channel.lowercased() {
        case "ateobreaking": return .init(name: "Ateo Breaking", color: Color(hex: "E0564F"))
        case "vcnews":       return .init(name: "vc.ru", color: Color(hex: "3D8BDB"))
        case "easy_qa_ru":   return .init(name: "easy QA", color: Color(hex: "1A9E8F"))
        case "media_apple":  return .init(name: "Apple Media", color: Color(hex: "8E8E93"))
        default:             return .init(name: channel, color: Color(hex: "8E8E93"))
        }
    }
}

extension Color {
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
