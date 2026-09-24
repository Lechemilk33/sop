import Foundation
import Observation
import SwiftData

/// The "Tell a story" journey. He chooses his own story (with a name he
/// picks, or none) or a question; then he talks; then it's saved. After
/// saving he can give it a name and choose who's in it, one step at a time,
/// and come back to "Saved".
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
        /// After saving: a name for the story.
        case renaming(Story)
        /// After saving: who's in the story.
        case choosingPeople(Story)
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

        // The family may have changed things while he talked, so everything
        // this story links to is looked up again.
        let isAnswer = kind == .question
        let links = StoryLinks(
            person: context.existing(aboutPerson),
            chapter: context.existing(seedChapter),
            question: isAnswer ? context.existing(prompt.question) : nil,
            questionPerson: isAnswer ? context.existing(prompt.aboutPerson) : nil,
            questionChapter: isAnswer ? context.existing(prompt.chapter) : nil,
            photo: isAnswer ? context.existing(prompt.photo) : nil
        )

        let story = Story(title: storyTitle(), promptText: isAnswer ? prompt.text : "")
        context.insert(story)
        story.audioData = audio
        story.audioFileExtension = finished.fileExtension
        story.duration = talked
        story.chapter = storyChapter(links)
        story.question = links.question
        story.photo = links.photo
        story.people = storyPeople(links)

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
        step = .choose
    }

    /// Leaving the screen never loses a story: a recording in progress is
    /// finished and saved first.
    func leave() {
        reader.stop()
        if case .recording = step {
            Task { await finishRecording() }
        }
    }

    // MARK: - After saving

    /// "Name it and add people": first the name.
    func nameSavedStory(_ story: Story) {
        step = .renaming(story)
    }

    /// Keeps the name he typed (an empty box keeps the current name), then
    /// on to who's in it.
    func saveName(_ name: String, for story: Story) {
        StoryEditing.rename(story, to: name)
        step = .choosingPeople(story)
    }

    /// Back to "Saved".
    func finishOrganizing(_ story: Story) {
        step = .saved(story)
    }

    // MARK: - Where the story goes

    /// Everything a new story links to, looked up after recording.
    private struct StoryLinks {
        let person: Person?
        let chapter: Chapter?
        let question: Question?
        let questionPerson: Person?
        let questionChapter: Chapter?
        let photo: Photo?
    }

    private func storyTitle() -> String {
        switch kind {
        case .own:
            let name = StoryTitles.cleaned(ownTitle)
            return name.isEmpty ? StoryTitles.untitled(on: Date()) : name
        case .question:
            return defaultTitle()
        }
    }

    private func storyChapter(_ links: StoryLinks) -> Chapter? {
        switch kind {
        case .own:
            if let chapter = links.chapter { return chapter }
            // A story about someone goes with the family's stories.
            let key = links.person == nil ? QuestionBank.moreStoriesKey : QuestionBank.familyKey
            return Seeder.chapter(forKey: key, in: context)
        case .question:
            return links.questionChapter ?? defaultChapter()
        }
    }

    /// The person he came from, and anyone in the question's photo.
    private func storyPeople(_ links: StoryLinks) -> [Person] {
        var candidates: [Person] = []
        if let person = links.person { candidates.append(person) }
        if let person = links.questionPerson { candidates.append(person) }
        candidates += links.photo?.people ?? []
        var people: [Person] = []
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
        case .start:
            return nextQuestionPrompt(in: nil)
        case .chapter(let chapter):
            return nextQuestionPrompt(in: chapter)
        }
    }

    /// The next question, from the chapter if it has questions of its own.
    /// Chapters he made (and More stories) have none, so the question comes
    /// from anywhere, but the story is still filed in his chapter.
    private func nextQuestionPrompt(in chapter: Chapter?) -> StoryPrompt {
        let descriptor = FetchDescriptor<Question>(predicate: #Predicate { $0.isHidden == false })
        var questions = (try? context.fetch(descriptor)) ?? []
        if let chapter {
            let own = questions.filter { $0.chapter?.persistentModelID == chapter.persistentModelID }
            if !own.isEmpty {
                questions = own
            }
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
        var prompt = StoryPrompt(question: question)
        if let chapter {
            prompt.chapter = chapter
        }
        return prompt
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
