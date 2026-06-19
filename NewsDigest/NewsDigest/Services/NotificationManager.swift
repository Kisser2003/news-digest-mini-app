import Foundation
import UserNotifications

/// Локальные напоминания о выпусках. Время настраивается. Это НЕ серверные
/// пуши — работают на бесплатном аккаунте, срабатывают по расписанию.
@MainActor
@Observable
final class NotificationManager {
    var isEnabled: Bool
    var morningHour: Int
    var morningMinute: Int
    var eveningHour: Int
    var eveningMinute: Int

    private let morningID = "edition.morning"
    private let eveningID = "edition.evening"
    private let defaults = UserDefaults.standard

    init() {
        isEnabled = defaults.bool(forKey: "remindersEnabled")
        morningHour = defaults.object(forKey: "mHour") as? Int ?? 8
        morningMinute = defaults.object(forKey: "mMin") as? Int ?? 0
        eveningHour = defaults.object(forKey: "eHour") as? Int ?? 21
        eveningMinute = defaults.object(forKey: "eMin") as? Int ?? 0
    }

    // Доступ для DatePicker (hourAndMinute).
    var morningDate: Date {
        get { date(morningHour, morningMinute) }
        set { let c = comps(newValue); morningHour = c.0; morningMinute = c.1; persist(); reschedule() }
    }
    var eveningDate: Date {
        get { date(eveningHour, eveningMinute) }
        set { let c = comps(newValue); eveningHour = c.0; eveningMinute = c.1; persist(); reschedule() }
    }

    func toggle() async {
        if isEnabled { disable() } else { await enable() }
    }

    func enable() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { isEnabled = false; persist(); return }
        isEnabled = true
        persist()
        reschedule()
    }

    func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [morningID, eveningID])
        isEnabled = false
        persist()
    }

    /// Перепланировать оба напоминания под текущие время и состояние.
    private func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningID, eveningID])
        guard isEnabled else { return }
        schedule(hour: morningHour, minute: morningMinute, id: morningID,
                 title: "Утренний выпуск 🌅", body: "Свежие посты за ночь готовы")
        schedule(hour: eveningHour, minute: eveningMinute, id: eveningID,
                 title: "Вечерний выпуск 🌙", body: "Что произошло за день")
    }

    private func schedule(hour: Int, minute: Int, id: String, title: String, body: String) {
        var time = DateComponents()
        time.hour = hour
        time.minute = minute
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }

    private func date(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }
    private func comps(_ date: Date) -> (Int, Int) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 8, c.minute ?? 0)
    }
    private func persist() {
        defaults.set(isEnabled, forKey: "remindersEnabled")
        defaults.set(morningHour, forKey: "mHour")
        defaults.set(morningMinute, forKey: "mMin")
        defaults.set(eveningHour, forKey: "eHour")
        defaults.set(eveningMinute, forKey: "eMin")
    }
}
