import SwiftUI

/// The way into the family area. If he lands here by accident, the biggest
/// thing on the screen takes him home. If the family code was reset from the
/// iPhone's Settings app, the family taps "Set a new code" and chooses one,
/// so a new code is never set by chance.
struct FamilyGateView: View {
    @Environment(Router.self) private var router
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services

    @State private var entered = ""
    @State private var newCode = ""
    @State private var note: String?
    @State private var isSettingNewCode = false

    private var isChoosingNewCode: Bool {
        !services.familyLock.isCodeSet
    }

    var body: some View {
        ScreenScaffold {
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
            if isChoosingNewCode, !isSettingNewCode {
                Text("The family code was reset.")
                    .appFont(.caption)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                BigButton("Set a new code", systemImage: Symbols.lock, tone: .outline, size: .compact) {
                    isSettingNewCode = true
                }
            } else {
                Text(prompt)
                    .appFont(.caption)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                CodeDots(count: entered.count)
                    .frame(maxWidth: .infinity)
                CodePad(onDigit: add, onDelete: deleteLast)
                if !isChoosingNewCode {
                    Text("Forgot the code? In the iPhone\u{2019}s Settings app, open Apps, then My Story, and turn on Reset family code. Nothing is deleted.")
                        .appFont(.caption)
                        .foregroundStyle(Palette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
        // A reset from the Settings app can arrive while this is open: start
        // cleanly rather than taking typed digits as a new code.
        .onChange(of: services.familyLock.isCodeSet) { _, _ in
            entered = ""
            newCode = ""
            note = nil
            isSettingNewCode = false
        }
    }

    private var prompt: String {
        if let note { return note }
        if isChoosingNewCode {
            return newCode.isEmpty ? "Choose a new family code" : "Type the new code again"
        }
        return "Family code"
    }

    private func add(_ digit: String) {
        guard entered.count < FamilyLock.codeLength else { return }
        note = nil
        entered += digit
        guard entered.count == FamilyLock.codeLength else { return }

        if isChoosingNewCode {
            if newCode.isEmpty {
                newCode = entered
                entered = ""
            } else if entered == newCode {
                services.familyLock.setCode(entered)
                openFamilyArea()
            } else {
                note = "Those didn't match. Choose a new code again."
                newCode = ""
                entered = ""
            }
            return
        }

        if services.familyLock.verify(entered) {
            openFamilyArea()
        } else {
            note = "That code didn't work. Try again."
            entered = ""
        }
    }

    private func deleteLast() {
        guard !entered.isEmpty else { return }
        entered.removeLast()
    }

    private func openFamilyArea() {
        entered = ""
        newCode = ""
        router.goHome()
        appState.isFamilyAreaPresented = true
    }
}
