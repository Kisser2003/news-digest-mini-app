import SwiftUI

@main
struct NewsDigestApp: App {
    @State private var readStore = ReadStore()

    var body: some Scene {
        WindowGroup {
            FeedView()
                .environment(readStore)
        }
    }
}
