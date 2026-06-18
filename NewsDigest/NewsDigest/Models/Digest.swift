import Foundation

/// Тип дайджеста, соответствует CHECK-ограничению в БД.
enum DigestType: String, Codable, Hashable {
    case morning
    case evening
    case manual

    /// Человекочитаемая подпись.
    var label: String {
        switch self {
        case .morning: return "Утренний"
        case .evening: return "Вечерний"
        case .manual:  return "Дайджест"
        }
    }

    /// Семантическая иконка типа.
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .evening: return "moon.stars.fill"
        case .manual:  return "list.bullet.rectangle.fill"
        }
    }
}

/// Одна запись дайджеста. Маппится на таблицу `public.digests`.
struct Digest: Identifiable, Codable, Hashable {
    let id: UUID
    let publishedAt: Date
    let type: DigestType
    let content: String

    enum CodingKeys: String, CodingKey {
        case id
        case publishedAt = "published_at"
        case type
        case content
    }
}

// MARK: - Производные представления для UI

extension Digest {
    /// Первая значимая строка — используется как заголовок карточки.
    var title: String {
        content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            ?? content
    }

    /// Остальной текст после заголовка — для превью (excerpt).
    var excerpt: String {
        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .dropFirst()
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        return lines.joined(separator: " ")
    }

    /// Текст для шаринга (заголовок + полное содержимое).
    func shareText(dateText: String) -> String {
        "\(dateText) · \(type.label) дайджест\n\n\(content)"
    }
}
