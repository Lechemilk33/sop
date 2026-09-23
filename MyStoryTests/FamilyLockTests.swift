import Foundation
import Testing
@testable import MyStory

@Suite("Family code")
struct FamilyLockTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "FamilyLockTests-\(UUID().uuidString)")!
    }

    private func makeLock() -> FamilyLock {
        FamilyLock(defaults: makeDefaults())
    }

    @Test func startsWithoutACode() {
        #expect(makeLock().isCodeSet == false)
    }

    @Test func verifiesOnlyTheRightCode() {
        let lock = makeLock()
        lock.setCode("2468")
        #expect(lock.isCodeSet)
        #expect(lock.verify("2468"))
        #expect(!lock.verify("1234"))
        #expect(!lock.verify(""))
    }

    @Test func resetClearsTheCode() {
        let lock = makeLock()
        lock.setCode("1357")
        lock.reset()
        #expect(!lock.isCodeSet)
        #expect(!lock.verify("1357"))
    }

    /// "Reset family code" in the iPhone's Settings app clears the code once,
    /// then switches itself back off.
    @Test func settingsSwitchResetsTheCodeOnce() {
        let defaults = makeDefaults()
        let lock = FamilyLock(defaults: defaults)
        lock.setCode("2468")

        lock.applyResetRequestIfNeeded()
        #expect(lock.isCodeSet, "Nothing happens while the switch is off")

        defaults.set(true, forKey: FamilyLock.resetRequestKey)
        lock.applyResetRequestIfNeeded()
        #expect(!lock.isCodeSet)
        #expect(defaults.bool(forKey: FamilyLock.resetRequestKey) == false)

        lock.setCode("1357")
        lock.applyResetRequestIfNeeded()
        #expect(lock.verify("1357"), "A new code survives the next launch")
    }

    @Test func validatesCodes() {
        #expect(FamilyLock.isValidCode("0000"))
        #expect(!FamilyLock.isValidCode("123"))
        #expect(!FamilyLock.isValidCode("12a4"))
    }
}
