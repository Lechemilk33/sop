import SwiftUI
import UIKit

/// Shows a photo stored in the app, or a calm placeholder while there isn't
/// one. It always takes exactly the frame it's given: `.fill` crops to that
/// frame (people's portraits are already framed around the face), `.fit`
/// shows the whole photo. Photos are decoded off the main thread the first
/// time, so screens never stutter; after that they show at once.
struct StoredImage: View {
    let cacheKey: String
    let data: Data?
    var placeholderSymbol: String = Symbols.person
    var contentMode: ContentMode = .fill
    /// The longest side, in pixels, to decode at. Small is faster and lighter.
    var maxPixelSize: CGFloat = ImageCache.thumbnailPixels

    @State private var loaded: ImageCache.Loaded?

    var body: some View {
        let key = ImageCache.key(for: cacheKey, data: data, maxPixelSize: maxPixelSize)
        let image = ImageCache.image(for: key, loaded: loaded)
        Rectangle()
            .fill(Palette.photoBackdrop)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if key == nil {
                    GeometryReader { proxy in
                        let side = min(proxy.size.width, proxy.size.height) * 0.46
                        Image(systemName: placeholderSymbol)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Palette.photoFigure)
                            .frame(width: side, height: side)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task(id: key) {
                loaded = await ImageCache.load(key, data: data, maxPixelSize: maxPixelSize)
            }
    }
}

/// A whole photo, never cropped, as tall as its shape needs up to a limit.
/// Used for the photos in stories and questions, so no one is cut out.
/// Until the photo is ready, a calm space of the same height holds its place.
struct WholePhoto: View {
    let cacheKey: String
    let data: Data?
    var maxHeight: CGFloat = 260

    @State private var loaded: ImageCache.Loaded?

    var body: some View {
        let key = ImageCache.key(for: cacheKey, data: data, maxPixelSize: ImageCache.largePixels)
        if let key {
            Group {
                if let image = ImageCache.image(for: key, loaded: loaded) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(maxWidth: .infinity, maxHeight: maxHeight)
                } else {
                    // The photo's own shape, read without decoding it, so
                    // nothing moves when it appears.
                    let size = data.flatMap(ImageProcessor.pixelSize(of:)) ?? CGSize(width: 4, height: 3)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Palette.photoBackdrop)
                        .aspectRatio(max(0.1, size.width / max(1, size.height)), contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: maxHeight)
                }
            }
            .accessibilityHidden(true)
            .task(id: key) {
                loaded = await ImageCache.load(key, data: data, maxPixelSize: ImageCache.largePixels)
            }
        }
    }
}

/// Decoded images, kept in memory so scrolling and going back are instant.
/// Images are decoded at the size they're shown, not at full size, and off
/// the main thread.
@MainActor
enum ImageCache {
    nonisolated static let thumbnailPixels: CGFloat = 720
    nonisolated static let largePixels: CGFloat = 1600

    /// A decoded image and the key it was decoded for.
    struct Loaded {
        let key: String
        let image: UIImage
    }

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    /// Names one photo at one size, or nil if there's no photo. The size and
    /// last bytes change whenever the photo does, so a new photo never shows
    /// the old one from the cache.
    static func key(for name: String, data: Data?, maxPixelSize: CGFloat) -> String? {
        guard let data, !data.isEmpty else { return nil }
        return "\(name)-\(data.count)-\(data.suffix(64).hashValue)-\(Int(maxPixelSize))"
    }

    /// The image for `key` if it's ready.
    static func image(for key: String?, loaded: Loaded?) -> UIImage? {
        guard let key else { return nil }
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        return loaded?.key == key ? loaded?.image : nil
    }

    /// Decodes the photo off the main thread and keeps it for next time.
    static func load(_ key: String?, data: Data?, maxPixelSize: CGFloat) async -> Loaded? {
        guard let key, let data, !data.isEmpty else { return nil }
        if let cached = cache.object(forKey: key as NSString) {
            return Loaded(key: key, image: cached)
        }
        let decoded = await Task.detached(priority: .userInitiated) {
            ImageProcessor.downsampled(data, maxPixelSize: maxPixelSize)
        }.value
        guard let decoded else { return nil }
        let pixels = decoded.size.width * decoded.size.height * decoded.scale * decoded.scale
        cache.setObject(decoded, forKey: key as NSString, cost: Int(pixels * 4))
        return Loaded(key: key, image: decoded)
    }
}
