import Foundation
import SwiftData

extension ModelContext {
    /// The same record, looked up again by its ID, or nil if it has been
    /// deleted since. Use it for anything held across an `await`, because the
    /// family (or iCloud) may have changed things in the meantime.
    func existing<Model: PersistentModel>(_ model: Model?) -> Model? {
        guard let model else { return nil }
        let id = model.persistentModelID
        var descriptor = FetchDescriptor<Model>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try? fetch(descriptor).first
    }
}
