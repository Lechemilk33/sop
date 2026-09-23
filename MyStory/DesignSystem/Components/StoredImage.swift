import SwiftUI
import UIKit

/// Shows a photo stored in the app, or a calm placeholder while there isn't one.
struct StoredImage: View {
    let cacheKey: String
    let data: Data?
    var placeholderSymbol: String = Symbols.person

    var body: some View {
        ZStack {
            Palette.photoBackdrop
            if let image = ImageCache.image(for: cacheKey, data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: placeholderSymbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Palette.photoFigure)
                    .padding(28)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Decoded images, kept in memory so scrolling and going back are instant.
@MainActor
enum ImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 120
        return cache
    }()

    static func image(for key: String, data: Data?) -> UIImage? {
        guard let data, !data.isEmpty else { return nil }
        let cacheKey = "\(key)-\(data.count)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: cacheKey)
        return image
    }
}
