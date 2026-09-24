import ImageIO
import UIKit
import Vision

/// Prepares photos for storage and display. Everything here is safe to call
/// off the main thread.
enum ImageProcessor {
    /// An old photo: a large copy for full-screen viewing and a small one for
    /// grids, both JPEG with the orientation baked in.
    struct Prepared: Sendable {
        let full: Data
        let thumbnail: Data
    }

    /// Someone's photo for My people: the whole photo, upright, and the
    /// square around their face.
    struct PreparedPortrait: Sendable {
        let full: Data
        let framing: PortraitFraming
    }

    static let fullSize: CGFloat = 2048
    static let thumbnailSize: CGFloat = 480
    /// Portraits are shown large on a person's page, so they're kept sharp.
    static let portraitSize: CGFloat = 900

    static func prepare(_ data: Data) -> Prepared? {
        guard let image = UIImage(data: data),
              let full = resized(image, maxDimension: fullSize).jpegData(compressionQuality: 0.85),
              let thumbnail = resized(image, maxDimension: thumbnailSize).jpegData(compressionQuality: 0.8)
        else { return nil }
        return Prepared(full: full, thumbnail: thumbnail)
    }

    static func preparePortrait(_ data: Data) -> PreparedPortrait? {
        guard let image = UIImage(data: data) else { return nil }
        let upright = resized(image, maxDimension: fullSize)
        guard let full = upright.jpegData(compressionQuality: 0.88), let cgImage = upright.cgImage else { return nil }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let framing = PortraitFraming.automatic(imageSize: size, faces: faces(in: cgImage))
        return PreparedPortrait(full: full, framing: framing)
    }

    /// The square portrait shown everywhere he sees this person.
    static func portrait(from fullData: Data, framing: PortraitFraming) -> Data? {
        guard let image = UIImage(data: fullData), let cgImage = image.cgImage else { return nil }
        // The framing was worked out on this same photo, but scale it in case
        // the stored copy was resized since.
        let scaleX = CGFloat(cgImage.width) / max(1, framing.imageSize.width)
        let scaleY = CGFloat(cgImage.height) / max(1, framing.imageSize.height)
        let crop = CGRect(
            x: framing.crop.minX * scaleX,
            y: framing.crop.minY * scaleY,
            width: framing.crop.width * scaleX,
            height: framing.crop.height * scaleY
        ).integral
        guard let cropped = cgImage.cropping(to: crop) else { return nil }
        let side = min(portraitSize, CGFloat(min(cropped.width, cropped.height)))
        let target = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    /// The whole photo in the square, with calm bars at the sides or top,
    /// for photos where cropping would cut someone out.
    static func wholePortrait(from fullData: Data) -> Data? {
        guard let image = UIImage(data: fullData) else { return nil }
        let side = portraitSize
        let scale = min(side / max(1, image.size.width), side / max(1, image.size.height))
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            // Palette.photoBackdrop, #E6DFD4.
            UIColor(red: 0xE6 / 255, green: 0xDF / 255, blue: 0xD4 / 255, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    /// A photo's size in pixels, read without decoding it.
    static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return CGSize(width: width, height: height)
    }

    /// The square around the faces in a stored photo, to start moving and
    /// zooming from.
    static func automaticFraming(for fullData: Data) -> PortraitFraming? {
        guard let image = UIImage(data: fullData), let cgImage = image.cgImage else { return nil }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        return PortraitFraming.automatic(imageSize: size, faces: faces(in: cgImage))
    }

    /// Frames a photo that was added before portraits were framed.
    static func framedPortrait(fromFull data: Data) -> Data? {
        guard let prepared = preparePortrait(data) else { return nil }
        return portrait(from: prepared.full, framing: prepared.framing)
    }

    /// Faces in the photo, in its pixels with the origin at the top left.
    static func faces(in cgImage: CGImage) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        return (request.results ?? []).map { PortraitFraming.pixelRect(fromNormalized: $0.boundingBox, imageSize: size) }
    }

    /// Decodes a photo at the size it will be shown, which uses far less
    /// memory than decoding it whole.
    static func downsampled(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as [CFString: Any] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
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
