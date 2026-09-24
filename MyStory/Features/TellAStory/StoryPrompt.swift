import Foundation

/// Where "Tell a story" was opened from, which decides what it offers.
enum PromptSeed {
    /// From Home: his own story, or a question from any chapter.
    case start
    /// A story about one person ("Tell a story about Emily").
    case about(Person)
    /// A story for one chapter.
    case chapter(Chapter)
}

/// The question on screen right now.
struct StoryPrompt {
    var text: String
    var chapter: Chapter?
    var question: Question?
    /// "Emily asked this one".
    var askedByName: String?
    /// The question in the asker's own voice.
    var askedAudio: Data?
    var photo: Photo?
    var aboutPerson: Person?
    var isFreeTalk: Bool

    init(question: Question) {
        let trimmed = question.text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = trimmed.isEmpty && question.photo != nil ? "Tell me about this photo." : trimmed
        chapter = question.chapter
        self.question = question
        askedByName = question.askedBy?.name
        askedAudio = question.recordedAudio
        photo = question.photo
        aboutPerson = nil
        isFreeTalk = question.isFreeTalk
    }

    init(text: String, aboutPerson: Person?, chapter: Chapter?) {
        self.text = text
        self.chapter = chapter
        question = nil
        askedByName = nil
        askedAudio = nil
        photo = nil
        self.aboutPerson = aboutPerson
        isFreeTalk = false
    }

    static let fallback = StoryPrompt(text: "What's on your mind today?", aboutPerson: nil, chapter: nil)
}
