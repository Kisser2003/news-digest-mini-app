import Foundation
import UserNotifications

/// Локальные напоминания о выпусках в 8:00 и 21:00 (по времени устройства).
/// Это НЕ серверные пуши — работают на бесплатном аккаунте, но срабатывают по
/// расписанию, а не по факту реального обновления данных.
@MainActor
@Observable
final class NotificationManager {
    var isEnabled: Bool = UserDefaults.standard.bool(forKey: "remindersEnabled")

    private let morningID = "edition.morning"
    private let eveningID = "edition.evening"

    func toggle() async {
        if isEnabled { disable() } else { await enable() }
    }

    func enable() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            isEnabled = false
            persist()
            return
        }
        schedule(hour: 8, minute: 0, id: morningID,
                 title: "Утренний выпуск 🌅", body: "Свежие посты за ночь готовы")
        schedule(hour: 21, minute: 0, id: eveningID,
                 title: "Вечерний выпуск 🌙", body: "Что произошло за день")
        isEnabled = true
        persist()
    }

    func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [morningID, eveningID])
        isEnabled = false
        persist()
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
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func persist() {
        UserDefaults.standard.set(isEnabled, forKey: "remindersEnabled")
    }
}
