import SwiftUI

/// Records a short clip in a family member's own voice: a hello for his
/// people page, or a question read the way they'd say it. The editor it's in
/// throws away a clip still recording when it closes (`discardClip()`), so
/// scrolling this row away never stops a recording.
struct VoiceClipField: View {
    let title: String
    let hint: String
    let clipID: String
    @Binding var audio: Data?
    @Binding var duration: Double

    @Environment(StoryRecorder.self) private var recorder
    @Environment(ClipPlayer.self) private var clipPlayer

    @State private var problem: String?

    /// Clips are a few minutes at most; anything bigger would weigh down
    /// every copy and sync.
    private let largestClip = 20_000_000

    private var isRecordingHere: Bool {
        recorder.clipName == clipID && recorder.state != .idle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(hint)
                .font(.subheadline)
                .foregroundStyle(Palette.softInk)
            if isRecordingHere {
                HStack {
                    if recorder.state == .finishing {
                        Label("Saving\u{2026}", systemImage: "waveform")
                            .foregroundStyle(Palette.softInk)
                    } else {
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
    }

    private func startRecording() async {
        clipPlayer.stop()
        problem = nil
        do {
            try await recorder.start(kind: .clip, clipName: clipID)
        } catch StoryRecorder.RecorderError.microphoneNotAllowed {
            problem = "The microphone is off for My Story. Turn it on in the iPhone's Settings app, under Apps \u{2192} My Story."
        } catch StoryRecorder.RecorderError.notEnoughSpace {
            problem = "The iPhone is too full to record. Free up some space in Settings \u{2192} General \u{2192} iPhone Storage, then try again."
        } catch StoryRecorder.RecorderError.busy {
            problem = "Something else is being recorded. Finish that first, then try again."
        } catch {
            problem = "Recording didn't start. Please try again."
        }
    }

    private func stopRecording() async {
        guard isRecordingHere, recorder.state != .finishing else { return }
        do {
            let finished = try await recorder.finish()
            defer { try? FileManager.default.removeItem(at: finished.fileURL) }
            let data = try Data(contentsOf: finished.fileURL)
            guard data.count <= largestClip else {
                problem = "That recording is too long to keep. Please record something shorter, a minute or two."
                return
            }
            audio = data
            duration = finished.bestDuration
        } catch {
            problem = "That recording didn't save. Please try again."
        }
    }
}
