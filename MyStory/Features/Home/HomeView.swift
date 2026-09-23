import SwiftUI

/// The first thing he sees: a greeting, today's date, and three big choices.
/// All three always fit on the screen without scrolling; on a small phone or
/// with very large text the buttons get a little shorter first.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .vertical) {
                content(buttonSize: .hero)
                    .frame(maxHeight: .infinity, alignment: .top)
                content(buttonSize: .large)
                    .frame(maxHeight: .infinity, alignment: .top)
                ScrollView {
                    content(buttonSize: .large)
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
        .background(Palette.paper.ignoresSafeArea())
    }

    private func content(buttonSize: ButtonSize) -> some View {
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

            Text("What would you like to do?")
                .appFont(.bodyBold)
                .foregroundStyle(Palette.ink)

            VStack(spacing: Metrics.sectionSpacing) {
                BigButton("Tell a story", systemImage: Symbols.tell, tone: .brick, size: buttonSize) {
                    router.push(.tellStory(.next))
                }
                BigButton("My people", systemImage: Symbols.people, tone: .blue, size: buttonSize) {
                    router.push(.myPeople)
                }
                BigButton("My life", systemImage: Symbols.life, tone: .marigold, size: buttonSize) {
                    router.push(.myLife)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}

/// The small, quiet "For family" button at the bottom of Home.
private struct FamilyEntryButton: View {
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: Symbols.lock)
                    .font(.system(size: 18, weight: .bold))
                    .accessibilityHidden(true)
                Text("For family")
                    .appFont(.caption)
            }
            .foregroundStyle(Palette.softInk)
            .padding(.horizontal, 24)
            .frame(minHeight: Metrics.minimumTarget)
            .overlay(shape.strokeBorder(Palette.edge, lineWidth: Metrics.staticBorder))
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("For family"))
    }
}
