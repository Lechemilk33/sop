import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData

/// Creates the store that holds every story, person and photo.
enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MyStorySchemaV1.self)
        let configuration = ModelConfiguration(
            "MyStory",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: inMemory ? .none : CloudSync.database
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: MyStoryMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

/// iCloud backup is off until the family turns it on (it needs the paid Apple
/// Developer Program). See README → "Turn on iCloud backup".
enum CloudSync {
    /// `MYSTORY_ICLOUD_SYNC` build setting, passed through Info.plist.
    static var isEnabled: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MyStoryICloudSync") as? String else { return false }
        return ["yes", "true", "1"].contains(value.lowercased())
    }

    static var containerIdentifier: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MyStoryCloudKitContainer") as? String,
              value.hasPrefix("iCloud."), !value.contains("$(") else { return nil }
        return value
    }

    static var database: ModelConfiguration.CloudKitDatabase {
        guard isEnabled, let containerIdentifier else { return .none }
        return .private(containerIdentifier)
    }

    enum Status: Equatable {
        case checking
        /// Stories are being copied to iCloud.
        case backingUp
        /// Backup is set up, but this iPhone isn't signed in to iCloud (or
        /// iCloud is off for My Story), so nothing is being copied.
        case notSignedIn
        /// This build doesn't use iCloud.
        case thisPhoneOnly
    }

    /// Whether stories are actually reaching iCloud right now.
    static func currentStatus() async -> Status {
        guard isEnabled, let containerIdentifier else { return .thisPhoneOnly }
        let account = try? await CKContainer(identifier: containerIdentifier).accountStatus()
        return account == .available ? .backingUp : .notSignedIn
    }
}

/// Listens to iCloud's own reports, so the family sees whether stories are
/// actually reaching iCloud, not only whether it's switched on. It also says
/// when a download from iCloud has finished, so another iPhone's copies of
/// the built-in chapters and questions can be tidied up.
@MainActor
@Observable
final class CloudSyncMonitor {
    /// When stories last reached iCloud.
    private(set) var lastUploadedAt: Date?
    /// The last upload failed, and none has worked since.
    private(set) var hasProblem = false

    @ObservationIgnored var onDownloadFinished: (@MainActor () -> Void)?
    @ObservationIgnored private var observer: NSObjectProtocol?

    func start() {
        guard CloudSync.isEnabled, observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event
            // Only finished events count; each also arrives when it starts.
            guard let event, let finishedAt = event.endDate else { return }
            let type = event.type
            let succeeded = event.succeeded
            MainActor.assumeIsolated {
                self?.record(type, succeeded: succeeded, at: finishedAt)
            }
        }
    }

    private func record(_ type: NSPersistentCloudKitContainer.EventType, succeeded: Bool, at date: Date) {
        switch type {
        case .export:
            if succeeded {
                lastUploadedAt = date
                hasProblem = false
            } else {
                hasProblem = true
            }
        case .import:
            if succeeded { onDownloadFinished?() }
        default:
            break
        }
    }
}
