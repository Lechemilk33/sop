import SwiftData
import SwiftUI

/// Hearing a story: one big play/pause button, who's in it, his words to read
/// along once the family has checked them, and "About this story" to name it
/// or sort it. The story starts by itself, so one tap is all it takes.
struct StoryPlayerView: View {
    let request: PlaybackRequest

    @Environment(\.modelContext) private var context
    @Environment(StoryPlayer.self) private var player
    @Environment(Router.self) private var router

    @State private var hasStarted = false

    var body: some View {
        ScreenScaffold {
            if let story = player.currentStory {
                StoryDetails(story: story)
                if player.couldNotPlay {
                    EmptyStateMessage(
                        title: "This story can't play right now",
                        message: "Your family can check it in the Family area."
                    )
                } else {
                    PlayPauseControl()
                }
                BigButton("About this story", systemImage: Symbols.organize, tone: .outline, size: .compact) {
                    // Paused, not stopped, so coming back carries on.
                    player.holdWhileOrganizing()
                    router.push(.storyDetails(story))
                }
                // Machine-written words can get names wrong, so he only sees
                // them after the family has checked the story.
                if story.hasTranscript, !story.needsReview {
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
        .onDisappear {
            if !player.isHolding {
                player.stop()
            }
        }
    }

    private var showsAnotherStoryButton: Bool {
        guard player.currentStory != nil else { return false }
        switch request {
        case .surprise: return true
        case .single, .queue: return player.hasFinished
        }
    }

    private func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        // Back from "About this story": carry on with the paused story.
        if player.resumeHold() { return }
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

/// The photo (whole, never cropped), the title, when he told it, and who's in it.
private struct StoryDetails: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let photo = story.photo {
                WholePhoto(cacheKey: photo.imageCacheKey, data: photo.imageData ?? photo.thumbnailData, maxHeight: 240)
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
            ForEach(story.sortedPeople) { person in
                PersonBadge(person: person, photoSize: 56)
            }
        }
    }
}

/// The big round glass play/pause button and the progress under it.
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
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 132, height: 132)
                    .contentShape(Circle())
                    .glassEffect(Glass.regular.tint(Palette.marigold).interactive(), in: Circle())
                    .background(Circle().fill(Palette.marigold))
                    .overlay(Circle().strokeBorder(Palette.marigoldRim, lineWidth: Metrics.tappableBorder))
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
