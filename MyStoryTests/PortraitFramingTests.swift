import Foundation
import Testing
@testable import MyStory

@Suite("Framing people's photos")
struct PortraitFramingTests {
    private let portraitPhoto = CGSize(width: 1500, height: 2000)
    private let widePhoto = CGSize(width: 2000, height: 1500)

    private func isInside(_ framing: PortraitFraming) -> Bool {
        let bounds = CGRect(origin: .zero, size: framing.imageSize)
        return bounds.insetBy(dx: -0.5, dy: -0.5).contains(framing.crop)
    }

    @Test func alwaysASquareInsideThePhoto() {
        for size in [portraitPhoto, widePhoto] {
            let framing = PortraitFraming.automatic(imageSize: size, faces: [])
            #expect(framing.crop.width == framing.crop.height)
            #expect(isInside(framing))
        }
    }

    @Test func withoutFacesItFavorsTheUpperMiddle() {
        let framing = PortraitFraming.automatic(imageSize: portraitPhoto, faces: [])
        #expect(framing.crop.width == 1500)
        #expect(framing.crop.minY > 0)
        #expect(framing.crop.midY < portraitPhoto.height / 2)
    }

    /// The head at the top of a tall photo is what got cut off before.
    @Test func keepsAFaceNearTheTopInFrame() {
        let face = CGRect(x: 600, y: 150, width: 300, height: 360)
        let framing = PortraitFraming.automatic(imageSize: portraitPhoto, faces: [face])
        #expect(framing.crop.contains(face))
        #expect(isInside(framing))
        #expect(framing.crop.width < portraitPhoto.width, "Zoomed in on the face")
    }

    @Test func fitsEveryoneWhenThereAreSeveralFaces() {
        let faces = [
            CGRect(x: 400, y: 700, width: 200, height: 240),
            CGRect(x: 1100, y: 650, width: 220, height: 260),
        ]
        let framing = PortraitFraming.automatic(imageSize: widePhoto, faces: faces)
        #expect(faces.allSatisfy { framing.crop.contains($0) })
        #expect(isInside(framing))
    }

    /// Faces spread wider than a square can hold: the biggest square,
    /// centered between them.
    @Test func widelySpreadFacesGetTheBiggestSquare() {
        let faces = [
            CGRect(x: 100, y: 700, width: 200, height: 240),
            CGRect(x: 1700, y: 650, width: 220, height: 260),
        ]
        let framing = PortraitFraming.automatic(imageSize: widePhoto, faces: faces)
        #expect(framing.crop.width == widePhoto.height)
        #expect(abs(framing.crop.midX - 1010) < 1)
        #expect(isInside(framing))
    }

    @Test func draggingRightShowsMoreOfTheLeft() {
        let start = PortraitFraming(imageSize: widePhoto, crop: CGRect(x: 500, y: 0, width: 1000, height: 1000))
        let moved = start.panned(by: CGSize(width: 100, height: 0), viewSide: 300)
        #expect(moved.crop.minX < start.crop.minX)
        #expect(moved.crop.width == start.crop.width)
    }

    @Test func neverPansOutsideThePhoto() {
        let start = PortraitFraming(imageSize: widePhoto, crop: CGRect(x: 100, y: 100, width: 1000, height: 1000))
        let moved = start.panned(by: CGSize(width: 5000, height: 5000), viewSide: 300)
        #expect(moved.crop.minX == 0)
        #expect(moved.crop.minY == 0)
        #expect(isInside(moved))
    }

    @Test func zoomStaysWithinLimits() {
        let start = PortraitFraming.automatic(imageSize: widePhoto, faces: [])
        #expect(start.zoomed(by: 0.1).crop.width == 1500, "Can't zoom out past the whole photo")
        let deep = start.zoomed(by: 100)
        #expect(abs(deep.zoom - PortraitFraming.maximumZoom) < 0.001)
        #expect(isInside(deep))
    }

    @Test func zoomingKeepsTheMiddle() {
        let start = PortraitFraming(imageSize: widePhoto, crop: CGRect(x: 500, y: 250, width: 1000, height: 1000))
        let zoomed = start.zoomed(by: 2)
        #expect(zoomed.crop.width == 500)
        #expect(zoomed.crop.midX == start.crop.midX)
        #expect(zoomed.crop.midY == start.crop.midY)
    }

    @Test func placementFillsTheView() {
        let framing = PortraitFraming(imageSize: widePhoto, crop: CGRect(x: 500, y: 250, width: 1000, height: 1000))
        let placement = framing.placement(viewSide: 300)
        #expect(placement.size.width == 600)
        #expect(placement.size.height == 450)
        #expect(placement.origin.x == -150)
        #expect(placement.origin.y == -75)
    }

    @Test func convertsVisionBoxes() {
        let box = CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25)
        let rect = PortraitFraming.pixelRect(fromNormalized: box, imageSize: CGSize(width: 2000, height: 1000))
        #expect(rect == CGRect(x: 500, y: 250, width: 1000, height: 250))
    }
}
