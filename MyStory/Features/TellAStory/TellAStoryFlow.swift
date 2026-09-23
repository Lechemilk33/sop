import Foundation
import Observation
import SwiftData

/// The "Tell a story" journey: a question, then listening, then "Saved".
@MainActor
@Observable
final class TellAStoryFlow {
    enum Step {
        case question
        case recording
        case saved(Story)
        case microphoneOff
    }

    private(set) var step: Step = .question
    private(set) var prompt: StoryPrompt = .fallback
    /// Shown gently when a recording was only a moment long.
    private(set) var showsTooShortNote = false
    private(set) var isSaving = false

    let seed: PromptSeed

    private let context: ModelContext
    private let recorder: StoryRecorder
    private let reader: QuestionReader
    private let transcription: TranscriptionService
    private let readsAutomatically: Bool

    @ObservationIgnored private var recentQuestionIDs: [UUID] = []
    @ObservationIgnored private var personPromptIndex = 0
    @ObservationIgnored private var lastPromptWasFreeTalk = false
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()

    /// Shorter than this is almost certainly a mistaken tap.
    private let minimumDuration: TimeInterval = 2

    init(
        seed: PromptSeed,
        context: ModelContext,
        recorder: StoryRecorder,
        reader: QuestionReader,
        transcription: TranscriptionService,
        readsAutomatically: Bool
    ) {
        self.seed = seed
        self.context = context
        self.recorder = recorder
        self.reader = reader
        self.transcription = transcription
        self.readsAutomatically = readsAutomatically
        prompt = makePrompt()
    }

    func toggleReading() {
        reader.toggle(text: prompt.text, recordedAudio: prompt.askedAudio)
    }

    /// Reads the question aloud when the family has turned that on.
    func readIfAutomatic() {
        if readsAutomatically {
            reader.read(text: prompt.text, recordedAudio: prompt.askedAudio)
        }
    }

    func nextQuestion() {
        reader.stop()
        showsTooShortNote = false
        prompt = makePrompt()
        readIfAutomatic()
    }

    func startRecording() async {
        reader.stop()
        showsTooShortNote = false
        recorder.onReachedSafetyLimit = { [weak self] in
            Task { await self?.finishRecording() }
        }
        do {
            try await recorder.start()
            step = .recording
        } catch {
            step = .microphoneOff
        }
    }

    func finishRecording() async {
        guard case .recording = step, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let finished: FinishedRecording
        do {
            finished = try await recorder.finish()
        } catch {
            step = .question
            return
        }

        if finished.duration < minimumDuration {
            try? FileManager.default.removeItem(at: finished.fileURL)
            showsTooShortNote = true
            step = .question
            return
        }

        guard let audio = try? Data(contentsOf: finished.fileURL) else {
            // The raw file stays in the recovery folder and is rescued next launch.
            step = .question
            return
        }

        let story = Story(title: defaultTitle(), promptText: prompt.text)
        context.insert(story)
        story.audioData = audio
        story.audioFileExtension = finished.fileExtension
        story.duration = finished.duration
        story.chapter = prompt.chapter ?? defaultChapter()
        story.question = prompt.question
        story.photo = prompt.photo
        if let person = prompt.aboutPerson {
            story.people = [person]
        }
        if let photoPeople = prompt.photo?.people, !photoPeople.isEmpty {
            var people = story.people ?? []
            for person in photoPeople where !people.contains(where: { $0.persistentModelID == person.persistentModelID }) {
                people.append(person)
            }
            story.people = people
        }

        do {
            try context.save()
            try? FileManager.default.removeItem(at: finished.fileURL)
            transcription.enqueue(story)
            Haptics.success()
            step = .saved(story)
        } catch {
            context.delete(story)
            step = .question
        }
    }

    /// "Tell another story".
    func startOver() {
        showsTooShortNote = false
        prompt = makePrompt()
        step = .question
        readIfAutomatic()
    }

    func leave() {
        reader.stop()
    }

    // MARK: - Choosing the question

    private func makePrompt() -> StoryPrompt {
        switch seed {
        case .about(let person):
            let texts = PersonPrompts.texts(for: person.name)
            let text = texts[personPromptIndex % texts.count]
            personPromptIndex += 1
            let family = Seeder.chapter(forKey: QuestionBank.familyKey, in: context)
            return StoryPrompt(text: text, aboutPerson: person, chapter: family)
        case .next:
            return nextQuestionPrompt(in: nil)
        case .chapter(let chapter):
            return nextQuestionPrompt(in: chapter)
        }
    }

    private func nextQuestionPrompt(in chapter: Chapter?) -> StoryPrompt {
        let descriptor = FetchDescriptor<Question>(predicate: #Predicate { $0.isHidden == false })
        var questions = (try? context.fetch(descriptor)) ?? []
        if let chapter {
            questions = questions.filter { $0.chapter?.persistentModelID == chapter.persistentModelID }
        }
        let candidates = questions.map { question in
            QuestionCandidate(
                id: question.uuid,
                chapterPriority: question.chapter?.askPriority ?? 50,
                isFamilyQuestion: !question.isBuiltIn,
                isFreeTalk: question.isFreeTalk,
                answerCount: question.answerCount,
                timesShown: question.timesShown,
                lastShownAt: question.lastShownAt,
                createdAt: question.createdAt
            )
        }
        let picked = QuestionPicker().pick(
            from: candidates,
            excluding: Set(recentQuestionIDs.suffix(6)),
            allowFreeTalk: chapter == nil && !lastPromptWasFreeTalk,
            using: &generator
        )
        guard let picked, let question = questions.first(where: { $0.uuid == picked.id }) else {
            return .fallback
        }
        question.timesShown += 1
        question.lastShownAt = Date()
        try? context.save()
        recentQuestionIDs.append(question.uuid)
        lastPromptWasFreeTalk = question.isFreeTalk
        return StoryPrompt(question: question)
    }

    private func defaultTitle() -> String {
        if prompt.isFreeTalk {
            return "My thoughts on \(DayText.full(Date()))"
        }
        if prompt.photo != nil {
            return "A story about a photo"
        }
        return prompt.text
    }

    private func defaultChapter() -> Chapter? {
        let key = prompt.isFreeTalk ? QuestionBank.thoughtsKey : QuestionBank.moreStoriesKey
        return Seeder.chapter(forKey: key, in: context)
    }
}
