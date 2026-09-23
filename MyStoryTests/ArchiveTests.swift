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
            photos: [],
            questions: [
                .init(
                    text: "Tell me about the lake house.",
                    askedBy: "Emily",
                    audioPath: "Questions/Emily asks - Tell me about the lake house.m4a",
                    photoPath: nil
                ),
            ]
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

    @Test func includesTheFamilysQuestions() {
        let html = ArchiveHTML.render(manifest())
        #expect(html.contains("Questions from the family"))
        #expect(html.contains("Asked by Emily"))
        #expect(html.contains("src=\"Questions/Emily%20asks%20-%20Tell%20me%20about%20the%20lake%20house.m4a\""))
    }

    @Test func leavesOutQuestionsWhenThereAreNone() {
        var plain = manifest()
        plain.questions = []
        #expect(!ArchiveHTML.render(plain).contains("Questions from the family"))
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
        #expect(decoded.questions.count == 1)
    }
}

@Suite("Recognizing recordings")
struct AudioFileTypeTests {
    private func data(_ header: String, padTo length: Int = 16) -> Data {
        var bytes = Array(header.utf8)
        bytes += Array(repeating: 0, count: max(0, length - bytes.count))
        return Data(bytes)
    }

    @Test func recognizesCAF() {
        #expect(AudioFileType.fileExtension(of: data("caff")) == "caf")
    }

    @Test func recognizesWAV() {
        var bytes = Array("RIFF".utf8) + [0x24, 0, 0, 0] + Array("WAVE".utf8)
        bytes += [0, 0, 0, 0]
        #expect(AudioFileType.fileExtension(of: Data(bytes)) == "wav")
    }

    @Test func recognizesM4A() {
        let bytes: [UInt8] = [0, 0, 0, 0x20] + Array("ftypM4A ".utf8)
        #expect(AudioFileType.fileExtension(of: Data(bytes)) == "m4a")
    }

    @Test func fallsBackForAnythingElse() {
        #expect(AudioFileType.fileExtension(of: Data(), fallback: "m4a") == "m4a")
        #expect(AudioFileType.fileExtension(of: data("junk"), fallback: "aac") == "aac")
    }
}
