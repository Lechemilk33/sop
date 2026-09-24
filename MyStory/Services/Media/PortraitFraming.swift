import Foundation

/// Which square part of a photo is someone's portrait in My people, and how
/// that square moves when the family drags or zooms it. Pure geometry, so it
/// can be tested anywhere.
///
/// All rectangles are in the photo's pixels, with the origin at the top left.
struct PortraitFraming: Equatable {
    /// The photo's size in pixels.
    var imageSize: CGSize
    /// The square that is shown.
    var crop: CGRect

    /// The most the family can zoom in, compared with the whole photo.
    static let maximumZoom: CGFloat = 5

    /// The largest square that fits in the photo.
    var largestSide: CGFloat {
        max(1, min(imageSize.width, imageSize.height))
    }

    /// How far in the square is zoomed: 1 is the largest square.
    var zoom: CGFloat {
        largestSide / max(1, crop.width)
    }

    /// A square around the main faces, with room for hair and shoulders and
    /// the eyes a little above the middle. Small faces in the background
    /// don't count, and if the main faces are too far apart for one square,
    /// the biggest face is kept whole rather than cutting everyone in half.
    /// With no faces, the upper middle of the photo, where heads usually are.
    static func automatic(imageSize: CGSize, faces: [CGRect]) -> PortraitFraming {
        let largest = max(1, min(imageSize.width, imageSize.height))
        let usable = faces.filter { $0.width > 0 && $0.height > 0 }
        guard let biggest = usable.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
            let origin = CGPoint(
                x: (imageSize.width - largest) / 2,
                y: (imageSize.height - largest) * 0.3
            )
            return PortraitFraming(imageSize: imageSize, crop: CGRect(origin: origin, size: CGSize(width: largest, height: largest)))
                .clamped()
        }
        let main = usable.filter { $0.width >= biggest.width * 0.6 }
        var union = main.reduce(biggest) { $0.union($1) }
        if max(union.width, union.height) * 1.2 > largest {
            union = biggest
        }
        let side = min(largest, max(union.width, union.height) * 2.4)
        let center = CGPoint(x: union.midX, y: union.midY + side * 0.05)
        let crop = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        return PortraitFraming(imageSize: imageSize, crop: crop).clamped()
    }

    /// The same square, kept inside the photo and no smaller than the
    /// maximum zoom allows.
    func clamped() -> PortraitFraming {
        let largest = largestSide
        let smallest = largest / Self.maximumZoom
        let side = min(largest, max(smallest, crop.width))
        let center = CGPoint(x: crop.midX, y: crop.midY)
        var origin = CGPoint(x: center.x - side / 2, y: center.y - side / 2)
        origin.x = min(max(0, origin.x), imageSize.width - side)
        origin.y = min(max(0, origin.y), imageSize.height - side)
        return PortraitFraming(imageSize: imageSize, crop: CGRect(origin: origin, size: CGSize(width: side, height: side)))
    }

    /// After a drag of `translation` points on a square view `viewSide`
    /// points wide. Dragging right shows more of the left of the photo.
    func panned(by translation: CGSize, viewSide: CGFloat) -> PortraitFraming {
        guard viewSide > 0 else { return self }
        let pixelsPerPoint = crop.width / viewSide
        var moved = crop
        moved.origin.x -= translation.width * pixelsPerPoint
        moved.origin.y -= translation.height * pixelsPerPoint
        return PortraitFraming(imageSize: imageSize, crop: moved).clamped()
    }

    /// After pinching by `magnification` (above 1 zooms in), keeping the
    /// middle of the square where it is.
    func zoomed(by magnification: CGFloat) -> PortraitFraming {
        guard magnification > 0 else { return self }
        let side = crop.width / magnification
        let center = CGPoint(x: crop.midX, y: crop.midY)
        let resized = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        return PortraitFraming(imageSize: imageSize, crop: resized).clamped()
    }

    /// Where to draw the whole photo so the square fills a view `viewSide`
    /// points wide: its size and its top-left corner, in points.
    func placement(viewSide: CGFloat) -> (size: CGSize, origin: CGPoint) {
        let pointsPerPixel = viewSide / max(1, crop.width)
        let size = CGSize(width: imageSize.width * pointsPerPixel, height: imageSize.height * pointsPerPixel)
        let origin = CGPoint(x: -crop.minX * pointsPerPixel, y: -crop.minY * pointsPerPixel)
        return (size, origin)
    }

    /// Converts Vision's face boxes (0–1, origin at the bottom left) into
    /// this photo's pixels.
    static func pixelRect(fromNormalized box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: box.minX * imageSize.width,
            y: (1 - box.maxY) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
    }
}
