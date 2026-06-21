import WidgetKit
import SwiftUI

struct NewsEntry: TimelineEntry {
    let date: Date
    let posts: [WidgetPost]
    static let placeholder = NewsEntry(date: .now, posts: [])
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NewsEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (NewsEntry) -> Void) {
        Task {
            let posts = (try? await WidgetAPI.fetchLatest(limit: 4)) ?? []
            completion(NewsEntry(date: .now, posts: posts))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewsEntry>) -> Void) {
        Task {
            let posts = (try? await WidgetAPI.fetchLatest(limit: 4)) ?? []
            let entry = NewsEntry(date: .now, posts: posts)
            // Совпадает с пулом бэкенда (каждые 30 мин).
            let next = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct NewsWidgetView: View {
    let entry: NewsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Новости")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if entry.posts.isEmpty {
                Spacer()
                Text("Нет свежих постов")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(Array(entry.posts.prefix(3))) { post in
                    PostRow(post: post)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct PostRow: View {
    let post: WidgetPost

    var body: some View {
        let channel = WidgetChannel.of(post.channel)
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(channel.color)
                .frame(width: 7, height: 7)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(post.text ?? "")
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(channel.color)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(post.publishedAt, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct NewsDigestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NewsDigestWidget", provider: Provider()) { entry in
            NewsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Новости")
        .description("Свежие посты из ваших каналов")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct NewsDigestWidgetBundle: WidgetBundle {
    var body: some Widget {
        NewsDigestWidget()
    }
}
