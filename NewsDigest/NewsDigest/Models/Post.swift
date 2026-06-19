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

    var imageRemoteURL: URL? { imageURL.flatMap(URL.init(string:)) }
    var telegramURL: URL? { link.flatMap(URL.init(string:)) }
    var hasText: Bool { !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Группировки для UI

/// Выпуск = все посты за один (день + утро/вечер).
struct Edition: Identifiable, Hashable {
    let id: String          // "2026-06-19-morning"
    let date: String
    let type: EditionType
    let publishedAt: Date   // время самого свежего поста (для шапки)
    let channels: [ChannelGroup]

    var totalPosts: Int { channels.reduce(0) { $0 + $1.posts.count } }
    var allPosts: [Post] { channels.flatMap(\.posts) }
}

/// Посты одного канала внутри выпуска.
struct ChannelGroup: Identifiable, Hashable {
    let id: String          // slug канала
    let channel: String
    let posts: [Post]
    var info: ChannelInfo { ChannelInfo.of(channel) }
}
