import Foundation

/// Форматирование даты выпуска в стиле «Сегодня, 08:00» / «Вчера, 20:00» /
/// «16 июня, 14:27».
enum DigestDateFormatter {
    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    static func string(for date: Date, calendar: Calendar = .current) -> String {
        let timeText = time.string(from: date)
        if calendar.isDateInToday(date) {
            return "Сегодня, \(timeText)"
        }
        if calendar.isDateInYesterday(date) {
            return "Вчера, \(timeText)"
        }
        return "\(dayMonth.string(from: date)), \(timeText)"
    }
}
