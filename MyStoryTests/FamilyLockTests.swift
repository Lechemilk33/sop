import Foundation
import Testing
@testable import MyStory

@Suite("Family code")
struct FamilyLockTests {
    private func makeLock() -> FamilyLock {
        let suite = "FamilyLockTests-\(UUID().uuidString)"
        return FamilyLock(defaults: UserDefaults(suiteName: suite)!)
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

    @Test func validatesCodes() {
        #expect(FamilyLock.isValidCode("0000"))
        #expect(!FamilyLock.isValidCode("123"))
        #expect(!FamilyLock.isValidCode("12a4"))
    }
}
