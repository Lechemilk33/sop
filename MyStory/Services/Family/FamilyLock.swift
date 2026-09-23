import CryptoKit
import Foundation
import Observation

/// The family code that keeps setup screens out of his way. It isn't a
/// security boundary; it stops the family area from being opened by accident.
/// Only a salted hash of the code is stored.
///
/// There is deliberately no Face ID or passcode fallback: it's his phone, so
/// his own face or passcode would open it. A forgotten code is reset from the
/// iPhone's Settings app (Settings → My Story → Reset family code).
@Observable
final class FamilyLock {
    static let codeLength = 4
    /// The switch in the iPhone's Settings app (see Resources/Settings.bundle).
    static let resetRequestKey = "resetFamilyCode"

    private let defaults: UserDefaults
    private static let hashKey = "familyCodeHash"
    private static let saltKey = "familyCodeSalt"

    /// Watched by the family gate, so it switches to "Choose a new family
    /// code" the moment a reset comes in from the Settings app.
    private(set) var isCodeSet: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isCodeSet = defaults.string(forKey: Self.hashKey) != nil
    }

    func setCode(_ code: String) {
        let salt = UUID().uuidString
        defaults.set(salt, forKey: Self.saltKey)
        defaults.set(Self.hash(code, salt: salt), forKey: Self.hashKey)
        isCodeSet = true
    }

    func verify(_ code: String) -> Bool {
        guard let stored = defaults.string(forKey: Self.hashKey),
              let salt = defaults.string(forKey: Self.saltKey) else { return false }
        return Self.hash(code, salt: salt) == stored
    }

    func reset() {
        defaults.removeObject(forKey: Self.hashKey)
        defaults.removeObject(forKey: Self.saltKey)
        isCodeSet = false
    }

    /// Clears the code if the family turned on "Reset family code" in the
    /// iPhone's Settings app, then turns the switch back off.
    func applyResetRequestIfNeeded() {
        guard defaults.bool(forKey: Self.resetRequestKey) else { return }
        reset()
        defaults.set(false, forKey: Self.resetRequestKey)
    }

    static func isValidCode(_ code: String) -> Bool {
        code.count == codeLength && code.allSatisfy(\.isNumber)
    }

    private static func hash(_ code: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + code).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
