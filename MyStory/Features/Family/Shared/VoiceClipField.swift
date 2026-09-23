import SwiftUI

/// Records a short clip in a family member's own voice: a hello for his
/// people page, or a question read the way they'd say it.
struct VoiceClipField: View {
    let title: String
    let hint: String
    let clipID: String
    @Binding var audio: Data?
    @Binding var duration: Double

    @Environment(StoryRecorder.self) private var recorder
    @Environment(ClipPlayer.self) private var clipPlayer

    @State private var isRecording = false
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(hint)
                .font(.subheadline)
                .foregroundStyle(Palette.softInk)
            if isRecording {
                HStack {
                    Label("Recording \(DurationText.clock(recorder.elapsed))", systemImage: "record.circle")
                        .foregroundStyle(Palette.brick)
                        .monospacedDigit()
                    Spacer()
                    Button("Stop") {
                        Task { await stopRecording() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.brick)
                }
            } else if audio != nil {
                HStack(spacing: 12) {
                    Button {
                        clipPlayer.toggle(id: clipID, data: audio)
                    } label: {
                        Label(
                            clipPlayer.isPlaying(clipID) ? "Stop" : "Play",
                            systemImage: clipPlayer.isPlaying(clipID) ? "stop.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    Button {
                        Task { await startRecording() }
                    } label: {
                        Label("Record again", systemImage: "mic")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button(role: .destructive) {
                        clipPlayer.stop()
                        audio = nil
                        duration = 0
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete recording")
                }
            } else {
                Button {
                    Task { await startRecording() }
                } label: {
                    Label("Record", systemImage: "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.brick)
            }
            if let problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(Palette.brick)
            }
        }
        .padding(.vertical, 4)
        .onDisappear {
            if isRecording {
                Task { await stopRecording() }
            }
        }
    }

    private func startRecording() async {
        clipPlayer.stop()
        problem = nil
        do {
            try await recorder.start(kind: .clip)
            isRecording = true
        } catch {
            problem = "The microphone isn't available. In the iPhone's Settings app, turn on the microphone for My Story."
        }
    }

    private func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        do {
            let finished = try await recorder.finish()
            defer { try? FileManager.default.removeItem(at: finished.fileURL) }
            audio = try Data(contentsOf: finished.fileURL)
            duration = finished.duration
        } catch {
            problem = "That recording didn't save. Please try again."
        }
    }
}
