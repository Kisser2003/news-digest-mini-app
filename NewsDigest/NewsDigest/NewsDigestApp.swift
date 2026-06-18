import SwiftUI

@main
struct NewsDigestApp: App {
    var body: some Scene {
        WindowGroup {
            FeedView()
                .preferredColorScheme(.dark)
        }
    }
}
