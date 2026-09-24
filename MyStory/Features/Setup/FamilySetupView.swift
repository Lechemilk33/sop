import Speech
import SwiftUI

/// First-run setup, done by a family member. Every system permission prompt
/// happens here, so he never meets one on his own.
struct FamilySetupView: View {
    private enum Step: Int, CaseIterable {
        case welcome
        case name
        case code
        case microphone
        case writing
        case done
    }

    @Environment(AppSettings.self) private var settings
    @Environment(AppServices.self) private var services
    @Environment(AppState.self) private var appState
    @Environment(StoryRecorder.self) private var recorder
    @Environment(TranscriptionService.self) private var transcription

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var firstCode = ""
    @State private var typedCode = ""
    @State private var codeNote: String?
    @State private var nameNote: String?
    @State private var microphoneAllowed: Bool?
    @State private var isPreparingWriting = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                        .tint(Palette.blue)
                        .accessibilityLabel("Setup progress")
                    content
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            footer
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(Backdrop(tone: nil))
        .onAppear {
            name = settings.personName
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            title("Let's set up My Story")
            paragraph("My Story is a simple place for him to record his life stories in his own voice, keep them by chapter, and see the important people in his life.")
            paragraph("Setup takes about two minutes and is meant for a family member. He doesn't need to be part of it, but he's welcome to watch.")
        case .name:
            title("What should the app call him?")
            paragraph("It greets him by name, like \u{201C}Good morning, Dave.\u{201D}")
            TextField("His first name", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.title2)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.edge, lineWidth: 2))
                .onChange(of: name) { _, newValue in
                    nameNote = nil
                    if newValue.count > 40 { name = String(newValue.prefix(40)) }
                }
            if let nameNote {
                Text(nameNote)
                    .font(.headline)
                    .foregroundStyle(Palette.brick)
            }
        case .code:
            title(firstCode.isEmpty ? "Choose a family code" : "Type the code again")
            paragraph("Four numbers. It opens the family area, where you add people, photos and questions. He won't need it.")
            paragraph("If it's ever forgotten, it can be reset from the iPhone\u{2019}s Settings app, under Apps \u{2192} My Story. Nothing is deleted.")
            if let codeNote {
                Text(codeNote)
                    .font(.headline)
                    .foregroundStyle(Palette.brick)
            }
            CodeDots(count: typedCode.count)
                .frame(maxWidth: .infinity)
            CodePad(onDigit: addDigit, onDelete: deleteDigit)
        case .microphone:
            title("Turn on the microphone")
            paragraph("So he can record his stories. The iPhone will ask once. Tap Allow.")
            if let microphoneAllowed {
                statusLine(
                    microphoneAllowed ? "The microphone is on." : "The microphone is off. You can turn it on later in the iPhone\u{2019}s Settings app, under Apps \u{2192} My Story.",
                    ok: microphoneAllowed
                )
            }
        case .writing:
            title("Writing his stories down")
            paragraph("The app writes down what he says, right on this iPhone, so the family can read along. Nothing is sent anywhere. The iPhone downloads a small language file once.")
            paragraph("His recordings are always the real story. The written words are only there to read along.")
            statusLine(writingStatus.text, ok: writingStatus.ok)
        case .done:
            title("All set")
            paragraph("Next, add the important people in his life, with a clear photo of each. You can also add old photos and your own questions.")
            paragraph("To come back here later, tap \u{201C}For family\u{201D} at the bottom of his home screen and enter your code.")
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            switch step {
            case .welcome:
                primary("Start") { step = .name }
            case .name:
                primary("Next") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        nameNote = "Type his first name first."
                        return
                    }
                    settings.personName = trimmed
                    step = .code
                }
            case .code:
                EmptyView()
            case .microphone:
                if microphoneAllowed == nil {
                    primary("Turn on the microphone") {
                        Task {
                            microphoneAllowed = await recorder.requestMicrophone()
                        }
                    }
                } else {
                    primary("Next") { step = .writing }
                }
            case .writing:
                if transcription.readiness == .ready || transcription.readiness == .unavailable {
                    primary("Next") { step = .done }
                } else {
                    primary(isPreparingWriting ? "Getting ready\u{2026}" : "Get it ready") {
                        Task { await prepareWriting() }
                    }
                    .disabled(isPreparingWriting)
                    secondary("Skip for now") { step = .done }
                }
            case .done:
                primary("Add people now") {
                    settings.hasCompletedSetup = true
                    appState.isFamilyAreaPresented = true
                }
                secondary("Go to his home screen") {
                    settings.hasCompletedSetup = true
                }
            }
            if let previous = previousStep {
                secondary("Back") { goBack(to: previous) }
            }
        }
    }

    /// Every step after the first can go back one, to fix a name or a code.
    private var previousStep: Step? {
        switch step {
        case .welcome: nil
        case .name: .welcome
        case .code: .name
        case .microphone: .code
        case .writing: .microphone
        case .done: .writing
        }
    }

    private func goBack(to previous: Step) {
        codeNote = nil
        nameNote = nil
        firstCode = ""
        typedCode = ""
        step = previous
    }

    // MARK: - Pieces

    private func title(_ text: String) -> some View {
        Text(text)
            .appFont(.screenTitle)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func statusLine(_ text: String, ok: Bool) -> some View {
        Label {
            Text(text)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(ok ? Palette.green : Palette.softInk)
        }
        .foregroundStyle(Palette.ink)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassActionStyle(tone: .blue, minHeight: 64))
    }

    /// A quieter choice; the whole width is tappable, not just the words.
    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.softInk)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var writingStatus: (text: String, ok: Bool) {
        switch transcription.readiness {
        case .ready: ("Ready. His stories will be written down.", true)
        case .unavailable: ("This iPhone can't write stories down. His recordings will still be saved.", false)
        case .downloading: ("Downloading the language file…", false)
        case .failed: ("That didn\u{2019}t work this time. Make sure the iPhone is online, then try again, or skip this for now. His recordings are saved either way.", false)
        case .needsDownload, .unknown: ("Tap Get it ready to download the language file.", false)
        }
    }

    // MARK: - Actions

    private func addDigit(_ digit: String) {
        guard typedCode.count < FamilyLock.codeLength else { return }
        codeNote = nil
        typedCode += digit
        guard typedCode.count == FamilyLock.codeLength else { return }
        if firstCode.isEmpty {
            firstCode = typedCode
            typedCode = ""
        } else if typedCode == firstCode {
            services.familyLock.setCode(typedCode)
            firstCode = ""
            typedCode = ""
            step = .microphone
        } else {
            codeNote = "Those didn't match. Let's start again."
            firstCode = ""
            typedCode = ""
        }
    }

    private func deleteDigit() {
        guard !typedCode.isEmpty else { return }
        typedCode.removeLast()
    }

    private func prepareWriting() async {
        isPreparingWriting = true
        defer { isPreparingWriting = false }
        _ = await SpeechPermission.request()
        await transcription.prepare()
    }
}

/// Speech-recognition permission, asked for during setup only.
enum SpeechPermission {
    static func request() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
