import SwiftUI
import ImageIO
import AVFoundation
import UIKit

/// Асинхронная загрузка картинок с даунсэмплингом и кешем.
///
/// Зачем не `AsyncImage`: он не кеширует декодированные изображения между
/// появлениями (в `LazyVStack` вьюхи пересоздаются при скролле → каждый раз
/// заново качает и декодирует) и грузит полноразмерный JPEG, ужимая его уже
/// после тяжёлого декода. Здесь: сетевой+дисковый кеш (URLCache), декод сразу
/// в нужный размер (ImageIO thumbnail) и кеш готовых `UIImage` (NSCache).
actor ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    /// Дедупликация одновременных запросов одного URL.
    private var inFlight: [NSString: Task<UIImage, Error>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024,
                                   diskCapacity: 256 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        cache.countLimit = 200
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL, maxPixel: CGFloat) async throws -> UIImage {
        let key = "\(url.absoluteString)@\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        if let task = inFlight[key] { return try await task.value }

        let task = Task<UIImage, Error> {
            let (data, _) = try await session.data(from: url)
            guard let image = Self.downsample(data: data, maxPixel: maxPixel) else {
                throw URLError(.cannotDecodeContentData)
            }
            return image
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let image = try await task.value
        cache.setObject(image, forKey: key, cost: image.estimatedBytes)
        return image
    }

    /// Размер дискового кэша картинок (байты).
    func diskUsageBytes() -> Int {
        session.configuration.urlCache?.currentDiskUsage ?? 0
    }

    /// Сбросить кэш картинок (память + диск).
    func clearCache() {
        cache.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
    }

    /// Декод сразу в целевой размер (в пикселях) — экономит память и время.
    private nonisolated static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixel, 1)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}

private extension UIImage {
    nonisolated var estimatedBytes: Int {
        guard let cg = cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}

/// Постер-кадр видео (первый кадр), с кешем. Тянет только начало файла.
actor VideoThumbnailLoader {
    static let shared = VideoThumbnailLoader()
    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [NSString: Task<UIImage?, Never>] = [:]

    func thumbnail(for url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = url.absoluteString as NSString
        if let cached = cache.object(forKey: key) { return cached }
        if let task = inFlight[key] { return await task.value }

        let task = Task<UIImage?, Never> {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            guard let cg = try? await generator.image(at: time).image else { return nil }
            return UIImage(cgImage: cg)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let image = await task.value
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    func clearCache() { cache.removeAllObjects() }
}

// MARK: - SwiftUI-обёртка

/// Кеширующая замена `AsyncImage` с тем же phase-API.
/// `targetWidth` — желаемая ширина в точках; конвертируется в пиксели по экрану.
struct CachedImage<Content: View>: View {
    let url: URL
    var targetWidth: CGFloat
    @ViewBuilder var content: (AsyncImagePhase) -> Content

    @Environment(\.displayScale) private var displayScale
    @State private var phase: AsyncImagePhase = .empty
    @State private var loadedURL: URL?

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        // Тот же url уже показан (ячейка вернулась в кадр) — ничего не трогаем,
        // без мигания. Сброс нужен только при смене url (переиспользование ячейки).
        if loadedURL == url, case .success = phase { return }
        phase = .empty
        do {
            let image = try await ImageLoader.shared.image(
                for: url, maxPixel: targetWidth * displayScale
            )
            phase = .success(Image(uiImage: image))
            loadedURL = url
        } catch {
            if !Task.isCancelled { phase = .failure(error) }
        }
    }
}
