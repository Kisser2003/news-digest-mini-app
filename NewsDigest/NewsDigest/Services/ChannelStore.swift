import Foundation
import Observation
import Supabase

/// Один канал: слаг + опциональные кастомные имя и цвет (hex).
struct ChannelItem: Decodable, Identifiable, Hashable {
    let slug: String
    let title: String?
    let color: String?
    var id: String { slug }
}

/// Управляемый список каналов. Источник правды — таблица `channels` в Supabase
/// (её же читает n8n). Пока таблицы нет — фолбэк на дефолтные 4.
@MainActor
@Observable
final class ChannelStore {
    private(set) var items: [ChannelItem] = ChannelStore.defaultItems

    /// Слаги в порядке отображения (для FeedViewModel).
    var slugs: [String] { items.map(\.slug) }

    static let defaults = ["Ateobreaking", "vcnews", "easy_qa_ru", "media_apple"]
    static var defaultItems: [ChannelItem] {
        defaults.map { ChannelItem(slug: $0, title: nil, color: nil) }
    }

    private let repo = SupabaseChannelRepository()

    func load() async {
        if let loaded = try? await repo.fetch(), !loaded.isEmpty {
            items = loaded
        } else {
            items = Self.defaultItems
        }
        ChannelInfo.applyCustom(items)
    }

    /// Добавить канал с опциональными именем и цветом.
    @discardableResult
    func add(_ raw: String, title: String?, color: String?) async -> Bool {
        guard let slug = Self.normalize(raw),
              !items.contains(where: { $0.slug.lowercased() == slug.lowercased() }) else { return false }
        let clean = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(ChannelItem(slug: slug, title: (clean?.isEmpty == false) ? clean : nil, color: color))
        ChannelInfo.applyCustom(items)                          // оптимистично
        try? await repo.add(slug: slug, title: clean, color: color, sortOrder: items.count)
        await load()
        return true
    }

    func remove(_ slug: String) async {
        items.removeAll { $0.slug.lowercased() == slug.lowercased() }
        ChannelInfo.applyCustom(items)
        try? await repo.remove(slug: slug)
        await load()
    }

    /// Нормализация ввода в Telegram-слаг (регистр сохраняем). nil — невалидно.
    static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        for prefix in ["https://", "http://", "t.me/", "telegram.me/", "@"] {
            if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
        }
        s = s.replacingOccurrences(of: "t.me/", with: "")
        s = String(s.prefix { $0 != "/" && $0 != "?" })
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        guard s.count >= 3, s.allSatisfy({ allowed.contains($0) }) else { return nil }
        return s
    }
}

/// Чтение/запись таблицы `channels` (публичный ключ; RLS разрешает anon write).
struct SupabaseChannelRepository {
    private let client = supabase
    private let table = "channels"

    private struct NewRow: Encodable {
        let slug: String
        let title: String?
        let color: String?
        let sort_order: Int
    }

    func fetch() async throws -> [ChannelItem] {
        try await client
            .from(table)
            .select("slug,title,color")
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func add(slug: String, title: String?, color: String?, sortOrder: Int) async throws {
        try await client.from(table)
            .insert(NewRow(slug: slug, title: title, color: color, sort_order: sortOrder))
            .execute()
    }

    func remove(slug: String) async throws {
        try await client.from(table).delete().eq("slug", value: slug).execute()
    }
}
