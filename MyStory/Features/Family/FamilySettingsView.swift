import SwiftUI
import UIKit

/// His name, text size, reading aloud, the microphone, writing stories down,
/// the family code and backup.
struct FamilySettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StoryRecorder.self) private var recorder
    @Environment(TranscriptionService.self) private var transcription
    @Environment(\.openURL) private var openURL

    @State private var isPreparingWriting = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                TextField("His first name", text: $settings.personName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            } header: {
                Text("His name")
            } footer: {
                Text("Used in the greeting, like \u{201C}Good morning, \(settings.displayName.isEmpty ? "Dave" : settings.displayName).\u{201D}")
            }

            Section {
                Picker("Text size", selection: $settings.textSize) {
                    ForEach(TextSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                Text("Good morning")
                    .appFont(.greeting)
                    .foregroundStyle(Palette.ink)
                    .environment(\.textScale, settings.textSize.scale)
                Toggle("Read each question out loud", isOn: $settings.readQuestionsAutomatically)
            } header: {
                Text("Reading")
            } footer: {
                Text("Text also grows with the iPhone's own text size (Settings → Accessibility → Display & Text Size). Reading can get harder later in the day, so go bigger if in doubt.")
            }

            Section("Microphone") {
                if recorder.isMicrophoneAllowed {
                    Label("On", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.green)
                } else if recorder.hasAskedForMicrophone {
                    Label("Off. Turn it on in the iPhone's Settings app.", systemImage: "mic.slash")
                        .foregroundStyle(Palette.brick)
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                } else {
                    Button("Turn on the microphone") {
                        Task { _ = await recorder.requestMicrophone() }
                    }
                }
            }

            Section {
                switch transcription.readiness {
                case .ready:
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.green)
                case .unavailable:
                    Label("This iPhone can't write stories down. Recordings are still saved.", systemImage: "info.circle")
                        .foregroundStyle(Palette.softInk)
                case .downloading:
                    Label("Downloading the language file…", systemImage: "arrow.down.circle")
                        .foregroundStyle(Palette.softInk)
                case .needsDownload, .failed, .unknown:
                    Button(isPreparingWriting ? "Getting ready…" : "Get it ready") {
                        Task {
                            isPreparingWriting = true
                            _ = await SpeechPermission.request()
                            await transcription.prepare()
                            isPreparingWriting = false
                        }
                    }
                    .disabled(isPreparingWriting)
                }
            } header: {
                Text("Writing stories down")
            } footer: {
                Text("Done on this iPhone. Nothing is sent anywhere.")
            }

            Section("Family code") {
                NavigationLink("Change the family code") {
                    ChangeCodeView()
                }
            }

            Section {
                BackupStatusRow()
            } header: {
                Text("Backup")
            } footer: {
                Text("Until iCloud backup is on, the stories live only on this iPhone. Make a copy with Save a copy of everything every few weeks.")
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersion)
                LabeledContent("Font", value: "Atkinson Hyperlegible Next (SIL OFL)")
            }
        }
        .familyBackground()
        .navigationTitle("Settings")
        .task { await transcription.refreshReadiness() }
    }
}

/// Set a new family code: type it, then type it again.
struct ChangeCodeView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var firstCode = ""
    @State private var typed = ""
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(firstCode.isEmpty ? "Type a new code" : "Type it again")
                .appFont(.screenTitle)
                .foregroundStyle(Palette.ink)
            if let note {
                Text(note)
                    .font(.headline)
                    .foregroundStyle(Palette.brick)
            }
            CodeDots(count: typed.count)
                .frame(maxWidth: .infinity)
            CodePad(onDigit: add, onDelete: deleteLast)
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle("Family code")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add(_ digit: String) {
        guard typed.count < FamilyLock.codeLength else { return }
        note = nil
        typed += digit
        guard typed.count == FamilyLock.codeLength else { return }
        if firstCode.isEmpty {
            firstCode = typed
            typed = ""
        } else if typed == firstCode {
            services.familyLock.setCode(typed)
            dismiss()
        } else {
            note = "Those didn't match. Let's start again."
            firstCode = ""
            typed = ""
        }
    }

    private func deleteLast() {
        guard !typed.isEmpty else { return }
        typed.removeLast()
    }
}

extension Bundle {
    /// "1.0 (1)".
    var appVersion: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
