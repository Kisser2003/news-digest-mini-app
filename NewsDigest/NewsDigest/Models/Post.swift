import Foundation

/// Тип выпуска.
enum EditionType: String, Codable, Hashable {
    case morning
    case evening

    var label: String { self == .morning ? "Утренний" : "Вечерний" }
    var icon: String { self == .morning ? "sunrise.fill" : "moon.stars.fill" }
}

/// Один пост из Telegram-канала. Маппится на таблицу `public.posts`.
struct Post: Identifiable, Codable, Hashable {
    let id: UUID
    let channel: String
    let messageID: Int?
    let text: String?
    let imageURL: String?
    let link: String?
    let publishedAt: Date
    let edition: EditionType
    let editionDate: String   // 'YYYY-MM-DD' (Postgres date)

    enum CodingKeys: String, CodingKey {
        case id, channel
        case messageID = "message_id"
        case text
        case imageURL = "image_url"
        case link
        case publishedAt = "published_at"
        case edition
        case editionDate = "edition_date"
    }

    /// Что лежит в `image_url`: картинка, видео (`.mp4` и т.п.) или ничего.
    /// Источник `tg.i-c-a.su` кладёт видео в то же поле, что и картинки.
    enum Media { case none, image, video }

    var media: Media {
        guard let path = imageURL?.split(separator: "?").first?.lowercased() else { return .none }
        if Self.videoExtensions.contains(where: path.hasSuffix) { return .video }
        return .image
    }

    private static let videoExtensions = [".mp4", ".mov", ".m4v", ".webm"]

    /// URL картинки (только если это действительно картинка, не видео).
    var imageRemoteURL: URL? { media == .image ? imageURL.flatMap(URL.init(string:)) : nil }
    /// URL видео (только если в `image_url` лежит видеофайл).
    var videoRemoteURL: URL? { media == .video ? imageURL.flatMap(URL.init(string:)) : nil }
    var telegramURL: URL? { link.flatMap(URL.init(string:)) }
    var hasText: Bool { !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Группировки для UI

/// Маршрут на экран канала (для navigationDestination).
struct ChannelRoute: Hashable {
    let channel: String
}

/// Посты одного канала внутри выпуска.
struct ChannelGroup: Identifiable, Hashable {
    let id: String          // slug канала
    let channel: String
    let posts: [Post]
    var info: ChannelInfo { ChannelInfo.of(channel) }
}
