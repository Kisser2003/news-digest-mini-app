import SwiftUI

@main
struct NewsDigestApp: App {
    @State private var readStore = ReadStore()
    @State private var notifications = NotificationManager()
    @State private var theme = ThemeStore()
    @State private var channels = ChannelStore()

    var body: some Scene {
        WindowGroup {
            FeedView()
                .environment(readStore)
                .environment(notifications)
                .environment(theme)
                .environment(channels)
                .tint(theme.accent.color)
                .preferredColorScheme(theme.appearance.colorScheme)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskID)) {
            await BackgroundRefresh.run()
        }
    }
}
