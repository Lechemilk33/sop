import Foundation
import Testing
@testable import MyStory

@Suite("File names in the saved copy")
struct FileNamingTests {
    @Test func removesForbiddenCharacters() {
        #expect(FileNaming.sanitized("Her first bike ride / 1985: \"the big day\"?") == "Her first bike ride 1985 the big day")
    }

    @Test func collapsesWhitespaceAndTrims() {
        #expect(FileNaming.sanitized("  The   lake\n\ttrip.  ") == "The lake trip")
    }

    @Test func fallsBackWhenEmpty() {
        #expect(FileNaming.sanitized("///", fallback: "Untitled") == "Untitled")
    }

    @Test func limitsLength() {
        #expect(FileNaming.sanitized(String(repeating: "a", count: 200), maxLength: 80).count == 80)
    }

    @Test func makesNamesUniqueIgnoringCase() {
        var taken = Set<String>()
        #expect(FileNaming.unique("Emily", ext: "jpg", taken: &taken) == "Emily.jpg")
        #expect(FileNaming.unique("emily", ext: "jpg", taken: &taken) == "emily 2.jpg")
        #expect(FileNaming.unique("Emily", ext: "jpg", taken: &taken) == "Emily 3.jpg")
        #expect(FileNaming.unique("Emily", ext: "m4a", taken: &taken) == "Emily.m4a")
    }

    @Test func folderName() {
        #expect(FileNaming.folderName(for: "Dave") == "Dave\u{2019}s Stories")
        #expect(FileNaming.folderName(for: " ") == "My Stories")
    }
}

@Suite("The page that plays everything")
struct ArchiveHTMLTests {
    private func manifest(title: String = "Her first bike ride", transcript: String = "She was five.") -> ArchiveManifest {
        ArchiveManifest(
            ownerName: "Dave",
            createdAt: Date(timeIntervalSince1970: 1_790_000_000),
            people: [
                .init(name: "Emily", relationship: "My daughter", facts: ["Lives in Chicago."], photoPath: "People/Emily.jpg", helloPath: nil),
            ],
            chapters: [
                .init(name: "Being a dad", stories: [
                    .init(
                        title: title,
                        prompt: "What were your kids like when they were little?",
                        recordedAt: Date(timeIntervalSince1970: 1_789_000_000),
                        durationSeconds: 245,
                        audioPath: "Stories/2026-09-12 Her first bike ride.m4a",
                        transcriptPath: "Stories/2026-09-12 Her first bike ride.txt",
                        transcript: transcript,
                        people: ["Emily"],
                        photoPath: nil,
                        year: nil
                    ),
                ]),
                .init(name: "Work", stories: []),
            ],
            photos: []
        )
    }

    @Test func includesStoriesPeopleAndAudio() {
        let html = ArchiveHTML.render(manifest())
        #expect(html.contains("Dave\u{2019}s stories"))
        #expect(html.contains("Being a dad"))
        #expect(html.contains("Her first bike ride"))
        #expect(html.contains("src=\"Stories/2026-09-12%20Her%20first%20bike%20ride.m4a\""))
        #expect(html.contains("My daughter"))
        #expect(html.contains("She was five."))
    }

    @Test func skipsEmptyChapters() {
        #expect(!ArchiveHTML.render(manifest()).contains(">Work<"))
    }

    @Test func escapesEverything() {
        let html = ArchiveHTML.render(manifest(title: "<script>alert(1)</script> & more", transcript: "\"quoted\" & 'single'"))
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;alert(1)&lt;/script&gt; &amp; more"))
        #expect(html.contains("&quot;quoted&quot; &amp; &#39;single&#39;"))
    }

    @Test func encodesPaths() {
        #expect(ArchiveHTML.url("Photos/Photo 001 & more.jpg") == "Photos/Photo%20001%20%26%20more.jpg")
    }

    @Test func manifestRoundTrips() throws {
        let original = manifest()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ArchiveManifest.self, from: original.jsonData())
        #expect(decoded == original)
        #expect(decoded.storyCount == 1)
    }
}
