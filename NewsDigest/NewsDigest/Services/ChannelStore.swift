import Foundation
import Observation
import Supabase

/// Управляемый список каналов. Источник правды — таблица `channels` в Supabase
/// (её же читает n8n, чтобы знать какие RSS тянуть). Пока таблицы нет — фолбэк
/// на дефолтные 4 канала, чтобы приложение работало.
@MainActor
@Observable
final class ChannelStore {
    /// Слаги каналов в порядке отображения (регистр как в Telegram-юзернейме).
    private(set) var slugs: [String] = ChannelStore.defaults

    static let defaults = ["Ateobreaking", "vcnews", "easy_qa_ru", "media_apple"]

    private let repo = SupabaseChannelRepository()

    func load() async {
        if let loaded = try? await repo.fetch(), !loaded.isEmpty {
            slugs = loaded
        } else {
            slugs = Self.defaults
        }
    }

    /// Добавить канал (принимает `@name`, `t.me/name`, ссылку или просто слаг).
    @discardableResult
    func add(_ raw: String) async -> Bool {
        guard let slug = Self.normalize(raw),
              !slugs.contains(where: { $0.lowercased() == slug.lowercased() }) else { return false }
        slugs.append(slug)                                   // оптимистично
        try? await repo.add(slug: slug, sortOrder: slugs.count)
        await load()
        return true
    }

    func remove(_ slug: String) async {
        slugs.removeAll { $0.lowercased() == slug.lowercased() }   // оптимистично
        try? await repo.remove(slug: slug)
        await load()
    }

    /// Нормализация ввода в Telegram-слаг. Регистр сохраняем (RSS-прокси
    /// и ссылки t.me чувствительны к нему). Возвращает nil, если ввод невалиден.
    static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        for prefix in ["https://", "http://", "t.me/", "telegram.me/", "@"] {
            if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
        }
        s = s.replacingOccurrences(of: "t.me/", with: "")
        s = String(s.prefix { $0 != "/" && $0 != "?" })       // отрезать путь/параметры
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        guard s.count >= 3, s.allSatisfy({ allowed.contains($0) }) else { return nil }
        return s
    }
}

/// Чтение/запись таблицы `channels` через Supabase (публичный ключ; нужна
/// RLS-политика, разрешающая anon insert/delete на этой таблице).
struct SupabaseChannelRepository {
    private let client = supabase
    private let table = "channels"

    private struct SlugRow: Decodable { let slug: String }
    private struct NewRow: Encodable { let slug: String; let sort_order: Int }

    func fetch() async throws -> [String] {
        let rows: [SlugRow] = try await client
            .from(table)
            .select("slug")
            .order("sort_order", ascending: true)
            .execute()
            .value
        return rows.map(\.slug)
    }

    func add(slug: String, sortOrder: Int) async throws {
        try await client.from(table).insert(NewRow(slug: slug, sort_order: sortOrder)).execute()
    }

    func remove(slug: String) async throws {
        try await client.from(table).delete().eq("slug", value: slug).execute()
    }
}
