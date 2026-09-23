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

    /// Questions invite a story; they never test memory.
    @Test func noQuestionQuizzes() {
        let banned = ["remember", "what year", "how old were", "what was the name", "can you recall"]
        for question in QuestionBank.questions {
            let text = question.text.lowercased()
            for phrase in banned {
                #expect(!text.contains(phrase), "\(question.key) sounds like a memory test: \(question.text)")
            }
        }
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

    @Test func personPromptsUseTheName() {
        let prompts = PersonPrompts.texts(for: "Emily")
        #expect(prompts.allSatisfy { $0.contains("Emily") })
        #expect(prompts.first == "Tell me about Emily.")
    }
}
