import SwiftUI

/// The first thing he sees: a greeting, today's date, and three big choices.
/// All three always fit on the screen without scrolling; on a small phone or
/// with very large text the tiles get a little shorter first.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(StoryPlayer.self) private var player
    @Environment(AppServices.self) private var services

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .vertical) {
                content(tileHeight: Metrics.heroButtonHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                content(tileHeight: Metrics.largeButtonHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                ScrollView {
                    content(tileHeight: Metrics.largeButtonHeight)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            FamilyEntryButton {
                router.push(.familyGate)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(HomeBackdrop())
        .onAppear {
            // Coming home ends anything that was waiting, like a paused story.
            player.stop()
            services.tidyIfNeeded()
        }
    }

    private func content(tileHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            TimelineView(.everyMinute) { timeline in
                VStack(alignment: .leading, spacing: 6) {
                    Text(Greeting.text(for: timeline.date, name: settings.displayName))
                        .appFont(.greeting)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(DayText.full(timeline.date))
                        .appFont(.subtitle)
                        .foregroundStyle(Palette.softInk)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            .padding(.bottom, 8)

            VStack(spacing: Metrics.sectionSpacing) {
                PlaceTile(
                    title: "Tell a story",
                    subtitle: "Record a memory in your own voice",
                    systemImage: Symbols.tell,
                    tone: .brick,
                    minHeight: tileHeight
                ) {
                    router.push(.tellStory(.start))
                }
                PlaceTile(
                    title: "My people",
                    subtitle: "Family and friends",
                    systemImage: Symbols.people,
                    tone: .blue,
                    minHeight: tileHeight
                ) {
                    router.push(.myPeople)
                }
                PlaceTile(
                    title: "My stories",
                    subtitle: "Listen, and keep them in order",
                    systemImage: Symbols.stories,
                    tone: .marigold,
                    minHeight: tileHeight
                ) {
                    router.push(.myStories)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }
}

/// The small, quiet "For family" button at the bottom of Home.
private struct FamilyEntryButton: View {
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button {
            TapGuard.perform(action)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: Symbols.lock)
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityHidden(true)
                Text("For family")
                    .appFont(.caption)
            }
            .foregroundStyle(Palette.softInk)
            .padding(.horizontal, 26)
            .frame(minHeight: Metrics.minimumTarget)
            .contentShape(Capsule())
            .glassEffect(.regular, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    contrast == .increased ? Palette.ink : Palette.edge,
                    lineWidth: contrast == .increased ? Metrics.increasedContrastBorder : Metrics.tappableBorder
                )
            )
        }
        .buttonStyle(PressDimStyle())
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("For family"))
    }
}
