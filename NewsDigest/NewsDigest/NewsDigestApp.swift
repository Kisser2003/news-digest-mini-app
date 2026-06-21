import SwiftUI

@main
struct NewsDigestApp: App {
    @State private var readStore = ReadStore()
    @State private var notifications = NotificationManager()
    @State private var theme = ThemeStore()

    var body: some Scene {
        WindowGroup {
            FeedView()
                .environment(readStore)
                .environment(notifications)
                .environment(theme)
                .tint(theme.accent.color)
                .preferredColorScheme(theme.appearance.colorScheme)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskID)) {
            await BackgroundRefresh.run()
        }
    }
}
