import SwiftUI

@main
struct NewsDigestApp: App {
    @State private var readStore = ReadStore()
    @State private var notifications = NotificationManager()

    var body: some Scene {
        WindowGroup {
            FeedView()
                .environment(readStore)
                .environment(notifications)
        }
    }
}
