import SwiftUI

/// The first thing he sees: a greeting, today's date, and three big choices.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScreenScaffold(showsTopBar: false) {
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
                BigButton("Tell a story", systemImage: Symbols.tell, tone: .brick, size: .hero) {
                    router.push(.tellStory(.next))
                }
                BigButton("My people", systemImage: Symbols.people, tone: .blue, size: .hero) {
                    router.push(.myPeople)
                }
                BigButton("My life", systemImage: Symbols.life, tone: .marigold, size: .hero) {
                    router.push(.myLife)
                }
            }
        } footer: {
            FamilyEntryButton {
                router.push(.familyGate)
            }
        }
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
            .padding(.horizontal, 22)
            .frame(minHeight: 56)
            .overlay(shape.strokeBorder(Palette.edge, lineWidth: Metrics.staticBorder))
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("For family"))
    }
}
