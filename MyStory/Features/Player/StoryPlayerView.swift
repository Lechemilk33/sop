import SwiftData
import SwiftUI

/// Hearing a story: one big play/pause button, who's in it, and his words to
/// read along. The story starts by itself, so one tap is all it takes.
struct StoryPlayerView: View {
    let request: PlaybackRequest

    @Environment(\.modelContext) private var context
    @Environment(StoryPlayer.self) private var player
    @Environment(Router.self) private var router

    @State private var hasStarted = false

    var body: some View {
        ScreenScaffold {
            if let story = player.currentStory {
                StoryDetails(story: story) { person in
                    router.push(.person(person))
                }
                PlayPauseControl()
                if story.hasTranscript {
                    InfoCard(spacing: 8) {
                        Text("In your words")
                            .appFont(.caption)
                            .foregroundStyle(Palette.softInk)
                        Text(story.transcript)
                            .appFont(.body)
                            .foregroundStyle(Palette.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if hasStarted {
                EmptyStateMessage(
                    title: "No stories yet",
                    message: "Tell a story first, and it will be here to listen to."
                )
            }
        } footer: {
            if showsAnotherStoryButton {
                BigButton("Play another story", systemImage: Symbols.shuffle, tone: .outline, size: .regular) {
                    playSurprise(excluding: player.currentStory)
                }
            }
        }
        .onAppear(perform: startIfNeeded)
        .onDisappear { player.stop() }
    }

    private var showsAnotherStoryButton: Bool {
        guard player.currentStory != nil else { return false }
        switch request {
        case .surprise: return true
        case .single: return player.hasFinished
        case .queue: return player.hasFinished
        }
    }

    private func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        switch request {
        case .single(let story):
            player.play([story])
        case .queue(let stories, let startIndex):
            player.play(stories, startingAt: startIndex)
        case .surprise:
            playSurprise(excluding: nil)
        }
    }

    private func playSurprise(excluding current: Story?) {
        guard let story = SurprisePicker.pick(in: context, excluding: current) else { return }
        player.play([story])
    }
}

/// Title, when he told it, the photo (if any) and who's in it.
private struct StoryDetails: View {
    let story: Story
    let onPerson: (Person) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let photo = story.photo {
                StoredImage(cacheKey: photo.imageCacheKey, data: photo.imageData ?? photo.thumbnailData, placeholderSymbol: Symbols.photo)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(DayText.toldByYou(story.recordedAt))
                    .appFont(.caption)
                    .foregroundStyle(Palette.softInk)
                Text(story.displayTitle)
                    .appFont(.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            let people = story.sortedPeople
            if !people.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        ForEach(people) { person in
                            PersonChip(person: person) { onPerson(person) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(people) { person in
                            PersonChip(person: person) { onPerson(person) }
                        }
                    }
                }
            }
        }
    }
}

/// The big round play/pause button and the progress under it.
private struct PlayPauseControl: View {
    @Environment(StoryPlayer.self) private var player

    var body: some View {
        let symbol = player.isPlaying ? Symbols.pause : (player.hasFinished ? Symbols.playAgain : Symbols.play)
        let label = player.isPlaying ? "Pause" : (player.hasFinished ? "Play it again" : "Play")
        VStack(spacing: 12) {
            Button {
                TapGuard.perform { player.togglePlayPause() }
            } label: {
                Image(systemName: symbol)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 136, height: 136)
                    .background(Circle().fill(Palette.marigold))
                    .overlay(Circle().strokeBorder(Palette.marigoldRim, lineWidth: Metrics.tappableBorder))
                    .contentShape(Circle())
            }
            .buttonStyle(PressDimStyle())
            .accessibilityLabel(Text(label))

            Text(label)
                .appFont(.button)
                .foregroundStyle(Palette.ink)
                .accessibilityHidden(true)

            ProgressTrack(value: player.progress)
            HStack {
                Text(DurationText.clock(player.currentTime))
                Spacer()
                Text(DurationText.clock(player.duration))
            }
            .appFont(.caption)
            .monospacedDigit()
            .foregroundStyle(Palette.softInk)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(DurationText.clock(player.currentTime)) of \(DurationText.clock(player.duration))"))
        }
        .frame(maxWidth: .infinity)
    }
}
