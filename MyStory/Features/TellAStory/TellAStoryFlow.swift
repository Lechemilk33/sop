import Foundation
import Observation
import SwiftData

/// The "Tell a story" journey. He chooses his own story (with a name he
/// picks, or none) or a question; then he talks; then it's saved.
@MainActor
@Observable
final class TellAStoryFlow {
    enum Step {
        /// "My own story" or "Answer a question".
        case choose
        /// Giving his own story a name, if he wants to, before he talks.
        case naming
        case question
        case recording
        case saved(Story)
        /// The story couldn't be stored right now, but the recording is safe
        /// on the iPhone and will be rescued automatically.
        case keptSafe
        case microphoneOff
    }

    enum Kind {
        /// Whatever he wants to talk about.
        case own
        /// An answer to a question.
        case question
    }

    private(set) var step: Step = .choose
    private(set) var kind: Kind = .own
    private(set) var prompt: StoryPrompt = .fallback
    /// The name he gives his own story. Empty means "name it by the date".
    var ownTitle = ""
    /// A calm note on the screen before recording, e.g. after a very short recording.
    private(set) var note: String?
    private(set) var isSaving = false
    /// Why the last recording stopped by itself, if it did.
    private(set) var stopReason: StoryRecorder.StopReason?

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
    private let minimumDuration: TimeInterval = 1.5

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
        if case .next = seed {
            kind = .question
            prompt = makePrompt()
            step = .question
        }
    }

    /// The person he's telling a story about, if he came from their page.
    var aboutPerson: Person? {
        if case .about(let person) = seed { return person }
        return nil
    }

    /// The chapter he came from, if any.
    var seedChapter: Chapter? {
        if case .chapter(let chapter) = seed { return chapter }
        return nil
    }

    /// Whether there's a choice screen to go back to.
    var canGoBackToChoice: Bool {
        if case .next = seed { return false }
        return true
    }

    // MARK: - Choosing how to start

    func chooseOwnStory() {
        reader.stop()
        note = nil
        kind = .own
        step = .naming
    }

    func chooseQuestion() {
        note = nil
        kind = .question
        prompt = makePrompt()
        step = .question
        readIfAutomatic()
    }

    /// From naming or a question back to the choice.
    func backToChoice() {
        reader.stop()
        note = nil
        step = .choose
    }

    func toggleReading() {
        reader.toggle(text: prompt.text, recordedAudio: prompt.askedAudio)
    }

    /// Reads the question aloud when the family has turned that on.
    func readIfAutomatic() {
        guard case .question = step, readsAutomatically else { return }
        reader.read(text: prompt.text, recordedAudio: prompt.askedAudio)
    }

    func nextQuestion() {
        reader.stop()
        note = nil
        prompt = makePrompt()
        readIfAutomatic()
    }

    // MARK: - Recording

    func startRecording() async {
        reader.stop()
        note = nil
        stopReason = nil
        recorder.onMustStop = { [weak self] reason in
            Task { await self?.finishRecording(stoppedBecause: reason) }
        }
        do {
            try await recorder.start()
            step = .recording
        } catch StoryRecorder.RecorderError.microphoneNotAllowed {
            step = .microphoneOff
        } catch StoryRecorder.RecorderError.notEnoughSpace {
            note = "The iPhone is too full to record right now. Ask your family to make some room."
        } catch {
            note = "Recording didn't start. Please try again."
        }
    }

    func finishRecording(stoppedBecause reason: StoryRecorder.StopReason? = nil) async {
        guard case .recording = step, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let finished: FinishedRecording
        do {
            finished = try await recorder.finish()
        } catch {
            step = .keptSafe
            return
        }

        let talked = finished.bestDuration
        if talked > 0, talked < minimumDuration {
            try? FileManager.default.removeItem(at: finished.fileURL)
            note = "That was very short. Take your time and try again."
            step = kind == .own ? .naming : .question
            return
        }

        guard let audio = try? Data(contentsOf: finished.fileURL) else {
            // The file stays in the recovery folder and becomes a story later.
            step = .keptSafe
            return
        }

        let isAnswer = kind == .question
        let story = Story(title: storyTitle(), promptText: isAnswer ? prompt.text : "")
        context.insert(story)
        story.audioData = audio
        story.audioFileExtension = finished.fileExtension
        story.duration = talked
        story.chapter = storyChapter()
        story.question = isAnswer ? prompt.question : nil
        story.photo = isAnswer ? prompt.photo : nil
        story.people = storyPeople()

        do {
            try context.save()
            try? FileManager.default.removeItem(at: finished.fileURL)
            transcription.enqueue(story)
            stopReason = reason
            Haptics.success()
            step = .saved(story)
        } catch {
            context.rollback()
            step = .keptSafe
        }
    }

    /// "Tell another story".
    func startOver() {
        note = nil
        stopReason = nil
        ownTitle = ""
        if case .next = seed {
            kind = .question
            prompt = makePrompt()
            step = .question
            readIfAutomatic()
        } else {
            step = .choose
        }
    }

    /// Leaving the screen never loses a story: a recording in progress is
    /// finished and saved first.
    func leave() {
        reader.stop()
        if case .recording = step {
            Task { await finishRecording() }
        }
    }

    // MARK: - Where the story goes

    private func storyTitle() -> String {
        switch kind {
        case .own:
            let name = StoryTitles.cleaned(ownTitle)
            return name.isEmpty ? StoryTitles.untitled(on: Date()) : name
        case .question:
            return defaultTitle()
        }
    }

    private func storyChapter() -> Chapter? {
        switch kind {
        case .own:
            return seedChapter ?? Seeder.chapter(forKey: QuestionBank.moreStoriesKey, in: context)
        case .question:
            return prompt.chapter ?? defaultChapter()
        }
    }

    /// The person he came from, and anyone in the question's photo.
    private func storyPeople() -> [Person] {
        var people: [Person] = []
        var candidates: [Person] = []
        if let person = aboutPerson { candidates.append(person) }
        if kind == .question {
            if let person = prompt.aboutPerson { candidates.append(person) }
            candidates += prompt.photo?.people ?? []
        }
        for person in candidates where !people.contains(where: { $0.persistentModelID == person.persistentModelID }) {
            people.append(person)
        }
        return people
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
        case .start, .next:
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
            var fallback = StoryPrompt.fallback
            fallback.chapter = chapter ?? Seeder.chapter(forKey: QuestionBank.thoughtsKey, in: context)
            return fallback
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
