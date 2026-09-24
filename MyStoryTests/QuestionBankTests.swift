import Foundation
import Testing
@testable import MyStory

@Suite("Built-in questions")
struct QuestionBankTests {
    @Test func keysAreUnique() {
        let keys = QuestionBank.questions.map(\.key)
        #expect(Set(keys).count == keys.count)
        let chapterKeys = QuestionBank.chapters.map(\.key)
        #expect(Set(chapterKeys).count == chapterKeys.count)
    }

    @Test func everyQuestionHasAChapter() {
        let chapterKeys = Set(QuestionBank.chapters.map(\.key))
        for question in QuestionBank.questions {
            #expect(chapterKeys.contains(question.chapterKey), "\(question.key) has no chapter")
        }
    }

    @Test func thereIsExactlyOneFreeTalkQuestion() {
        let freeTalk = QuestionBank.questions.filter(\.isFreeTalk)
        #expect(freeTalk.count == 1)
        #expect(freeTalk.first?.key == QuestionBank.freeTalkKey)
    }

    /// Words that turn an invitation into a memory test, or ask about the
    /// last few days, which fade first with Alzheimer's.
    static let quizPhrases = [
        "remember", "recall", "forget", "memor", "what year", "how old were", "name",
        "very first", "farthest", "do you know", "this week", "last week", "lately",
        "yesterday", "this morning", "what day",
    ]

    /// Questions invite a story; they never test memory.
    @Test func noQuestionQuizzes() {
        for question in QuestionBank.questions {
            let text = question.text.lowercased()
            for phrase in Self.quizPhrases {
                #expect(!text.contains(phrase), "\(question.key) sounds like a memory test: \(question.text)")
            }
        }
    }

    @Test func personPromptsNeverQuiz() {
        for prompt in PersonPrompts.texts(for: "Emily") {
            let text = prompt.lowercased()
            for phrase in Self.quizPhrases {
                #expect(!text.contains(phrase), "Sounds like a memory test: \(prompt)")
            }
        }
    }

    @Test func keysFollowTheirChapter() {
        for question in QuestionBank.questions {
            #expect(question.key.hasPrefix(question.chapterKey + "."), "\(question.key) is filed under \(question.chapterKey)")
        }
    }

    @Test func everyChapterHasQuestionsToAsk() {
        let asked = Set(QuestionBank.questions.map(\.chapterKey))
        for chapter in QuestionBank.chapters where chapter.key != QuestionBank.moreStoriesKey {
            #expect(asked.contains(chapter.key), "\(chapter.name) has no questions")
        }
        #expect(QuestionBank.questions.count >= 140)
    }

    @Test func noQuestionIsRepeated() {
        let texts = QuestionBank.questions.map { $0.text.lowercased() }
        #expect(Set(texts).count == texts.count)
    }

    @Test func questionsAreShortAndSingle() {
        for question in QuestionBank.questions {
            #expect(question.text.count <= 80, "\(question.key) is long")
            #expect(question.text.filter { $0 == "?" }.count <= 1, "\(question.key) asks more than one thing")
        }
    }

    @Test func recentDecadesAreAskedFirst() throws {
        let parent = try #require(QuestionBank.chapterSeed(forKey: "parent"))
        let work = try #require(QuestionBank.chapterSeed(forKey: "work"))
        let growingUp = try #require(QuestionBank.chapterSeed(forKey: "growing-up"))
        #expect(parent.askPriority < growingUp.askPriority)
        #expect(work.askPriority < growingUp.askPriority)
    }

    @Test func chapterPromptsInviteAndUseTheName() {
        let prompts = ChapterPrompts.texts(for: "  Fishing   trips ")
        #expect(prompts.first == "Tell me a story about \u{201C}Fishing trips\u{201D}.")
        #expect(prompts.allSatisfy { $0.contains("\u{201C}Fishing trips\u{201D}") })
        for prompt in prompts {
            let text = prompt.lowercased()
            for phrase in Self.quizPhrases {
                #expect(!text.contains(phrase), "Sounds like a memory test: \(prompt)")
            }
        }
        #expect(ChapterPrompts.texts(for: " ") == ["Tell me a story."])
    }

    @Test func personPromptsUseTheName() {
        let prompts = PersonPrompts.texts(for: "Emily")
        #expect(prompts.allSatisfy { $0.contains("Emily") })
        #expect(prompts.first == "Tell me about Emily.")
        #expect(PersonPrompts.texts(for: "  ").first == "Tell me about them.")
    }
}
