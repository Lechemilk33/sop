import UIKit

/// Prepares photos for storage: a large copy for full-screen viewing and a
/// small one for grids, both as JPEG with the orientation baked in.
enum ImageProcessor {
    struct Prepared: Sendable {
        let full: Data
        let thumbnail: Data
    }

    static let fullSize: CGFloat = 2048
    static let thumbnailSize: CGFloat = 480

    /// Safe to call off the main thread.
    static func prepare(_ data: Data) -> Prepared? {
        guard let image = UIImage(data: data),
              let full = resized(image, maxDimension: fullSize).jpegData(compressionQuality: 0.85),
              let thumbnail = resized(image, maxDimension: thumbnailSize).jpegData(compressionQuality: 0.8)
        else { return nil }
        return Prepared(full: full, thumbnail: thumbnail)
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
