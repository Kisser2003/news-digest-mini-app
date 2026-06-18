import Foundation
import Supabase

/// Конфигурация и единый экземпляр Supabase-клиента.
///
/// ⚠️ Здесь используется ТОЛЬКО публичный `anon`-ключ. Сервисный
/// (`service_role`) ключ в клиентское приложение класть нельзя — он живёт
/// исключительно в n8n.
enum SupabaseConfig {
    /// `https://<PROJECT_REF>.supabase.co`
    static let supabaseURL = URL(string: "https://YOUR_PROJECT_REF.supabase.co")!

    /// anon / public ключ из Supabase → Project Settings → API.
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

    /// Декодер с поддержкой ISO-8601 timestamptz (включая дробные секунды).
    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = isoWithFractional.date(from: raw) ?? isoPlain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Не удалось распарсить дату: \(raw)"
            )
        }
        return decoder
    }()
}

/// Глобально доступный сконфигурированный клиент.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.supabaseURL,
    supabaseKey: SupabaseConfig.supabaseAnonKey,
    options: .init(
        db: .init(encoder: JSONEncoder(), decoder: SupabaseConfig.jsonDecoder)
    )
)
