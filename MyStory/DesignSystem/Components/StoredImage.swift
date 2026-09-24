import SwiftUI
import UIKit

/// Shows a photo stored in the app, or a calm placeholder while there isn't
/// one. It always takes exactly the frame it's given: `.fill` crops to that
/// frame (people's portraits are already framed around the face), `.fit`
/// shows the whole photo.
struct StoredImage: View {
    let cacheKey: String
    let data: Data?
    var placeholderSymbol: String = Symbols.person
    var contentMode: ContentMode = .fill
    /// The longest side, in pixels, to decode at. Small is faster and lighter.
    var maxPixelSize: CGFloat = ImageCache.thumbnailPixels

    var body: some View {
        Rectangle()
            .fill(Palette.photoBackdrop)
            .overlay {
                if let image = ImageCache.image(for: cacheKey, data: data, maxPixelSize: maxPixelSize) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
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
    }
}

/// A whole photo, never cropped, as tall as its shape needs up to a limit.
/// Used for the photos in stories and questions, so no one is cut out.
struct WholePhoto: View {
    let cacheKey: String
    let data: Data?
    var maxHeight: CGFloat = 260

    var body: some View {
        if let image = ImageCache.image(for: cacheKey, data: data, maxPixelSize: ImageCache.largePixels) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: maxHeight)
                .accessibilityHidden(true)
        }
    }
}

/// Decoded images, kept in memory so scrolling and going back are instant.
/// Images are decoded at the size they're shown, not at full size.
@MainActor
enum ImageCache {
    static let thumbnailPixels: CGFloat = 720
    static let largePixels: CGFloat = 1600

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func image(for key: String, data: Data?, maxPixelSize: CGFloat = thumbnailPixels) -> UIImage? {
        guard let data, !data.isEmpty else { return nil }
        // The size and last bytes change whenever the photo does, so a new
        // photo never shows the old one from the cache.
        let fingerprint = "\(data.count)-\(data.suffix(64).hashValue)"
        let cacheKey = "\(key)-\(fingerprint)-\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard let image = ImageProcessor.downsampled(data, maxPixelSize: maxPixelSize) else { return nil }
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        cache.setObject(image, forKey: cacheKey, cost: Int(pixels * 4))
        return image
    }
}
