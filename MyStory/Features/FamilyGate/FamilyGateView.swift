import SwiftUI

/// The way into the family area. If he lands here by accident, the biggest
/// thing on the screen takes him home.
struct FamilyGateView: View {
    @Environment(Router.self) private var router
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services

    @State private var entered = ""
    @State private var showsWrongCode = false

    var body: some View {
        ScreenScaffold(showsTopBar: false) {
            SectionHeader(title: "For family", systemImage: Symbols.lock, tone: .ink)
            Text("This part is for setting things up.")
                .appFont(.bodyBold)
                .foregroundStyle(Palette.softInk)
            BigButton("Go back home", systemImage: Symbols.home, tone: .ink, size: .large) {
                router.goHome()
            }
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 2)
                .padding(.vertical, 4)
            Text(showsWrongCode ? "That code didn't work. Try again." : "Family code")
                .appFont(.caption)
                .foregroundStyle(showsWrongCode ? Palette.brick : Palette.softInk)
            CodeDots(count: entered.count)
                .frame(maxWidth: .infinity)
            CodePad(onDigit: add, onDelete: deleteLast)
            Button("Forgot the code?") {
                Task {
                    if await FamilyLock.unlockWithDeviceOwner() {
                        openFamilyArea()
                    }
                }
            }
            .appFont(.caption)
            .foregroundStyle(Palette.softInk)
            .frame(maxWidth: .infinity, minHeight: Metrics.minimumTarget)
        }
    }

    private func add(_ digit: String) {
        guard entered.count < FamilyLock.codeLength else { return }
        showsWrongCode = false
        entered += digit
        guard entered.count == FamilyLock.codeLength else { return }
        if services.familyLock.verify(entered) {
            openFamilyArea()
        } else {
            showsWrongCode = true
            entered = ""
        }
    }

    private func deleteLast() {
        guard !entered.isEmpty else { return }
        entered.removeLast()
    }

    private func openFamilyArea() {
        entered = ""
        router.goHome()
        appState.isFamilyAreaPresented = true
    }
}
