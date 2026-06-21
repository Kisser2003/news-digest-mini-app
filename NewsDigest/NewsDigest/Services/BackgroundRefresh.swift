import Foundation
import BackgroundTasks
import UserNotifications

/// Фоновое обновление: iOS периодически будит приложение → проверяем Supabase
/// и шлём локальное уведомление о новых постах. На бесплатном аккаунте это
/// единственный путь (серверный APNs недоступен). Время будит iOS — не мгновенно.
enum BackgroundRefresh {
    static let taskID = "com.kisser.newsdigest.refresh"
    private static let lastTopKey = "bg.lastTopPublishedAt"
    private static let enabledKey = "newPostsNotify"

    /// Запланировать следующий фоновый заход (iOS решит точное время).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Зафиксировать «сейчас» как базовую точку — чтобы при включении тумблера
    /// не прилетело уведомление про все уже существующие посты.
    static func seedBaseline() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastTopKey)
    }

    /// Тело фоновой задачи: проверить новые посты и уведомить, если включено.
    static func run() async {
        schedule()  // сразу планируем следующий заход
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }

        let posts = (try? await SupabasePostRepository().fetchPosts(limit: 50)) ?? []
        guard let newest = posts.first else { return }

        let last = UserDefaults.standard.double(forKey: lastTopKey)
        let newestTs = newest.publishedAt.timeIntervalSince1970
        guard newestTs > last else { return }   // ничего нового

        UserDefaults.standard.set(newestTs, forKey: lastTopKey)
        guard last > 0 else { return }           // первый прогон — только засеять базу

        let newCount = posts.filter { $0.publishedAt.timeIntervalSince1970 > last }.count
        await notify(count: newCount, latest: newest)
    }

    private static func notify(count: Int, latest: Post) async {
        let content = UNMutableNotificationContent()
        content.title = count > 1 ? "\(count) новых постов" : "Новый пост"
        let channel = ChannelInfo.of(latest.channel).displayName
        let text = (latest.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = text.isEmpty ? channel : "\(channel): \(text.prefix(90))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "newposts.\(Int(latest.publishedAt.timeIntervalSince1970))",
            content: content,
            trigger: nil   // доставить немедленно
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
