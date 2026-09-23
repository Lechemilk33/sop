import CryptoKit
import Foundation
import LocalAuthentication

/// The family code that keeps setup screens out of his way. It isn't a
/// security boundary; it stops the family area from being opened by accident.
/// Only a salted hash of the code is stored.
final class FamilyLock {
    static let codeLength = 4

    private let defaults: UserDefaults
    private let hashKey = "familyCodeHash"
    private let saltKey = "familyCodeSalt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isCodeSet: Bool {
        defaults.string(forKey: hashKey) != nil
    }

    func setCode(_ code: String) {
        let salt = UUID().uuidString
        defaults.set(salt, forKey: saltKey)
        defaults.set(Self.hash(code, salt: salt), forKey: hashKey)
    }

    func verify(_ code: String) -> Bool {
        guard let stored = defaults.string(forKey: hashKey),
              let salt = defaults.string(forKey: saltKey) else { return false }
        return Self.hash(code, salt: salt) == stored
    }

    func reset() {
        defaults.removeObject(forKey: hashKey)
        defaults.removeObject(forKey: saltKey)
    }

    static func isValidCode(_ code: String) -> Bool {
        code.count == codeLength && code.allSatisfy(\.isNumber)
    }

    /// If the code is forgotten: Face ID, Touch ID or the iPhone passcode.
    @MainActor
    static func unlockWithDeviceOwner() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Open the family area"
            )
        } catch {
            return false
        }
    }

    private static func hash(_ code: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + code).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
