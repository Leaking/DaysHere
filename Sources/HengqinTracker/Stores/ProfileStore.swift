import Combine
import Foundation
import HengqinCore

/// Owns the user's `LocationProfile` list and current selection. Persists to
/// `Application Support/HengqinTracker/profiles.json`. Records live in a
/// sibling `records/` directory, one JSON file per profile.
///
/// Switching the active profile is a published change; observers (the
/// `ResidencyStore`) should reload from the new profile's records URL and
/// re-subscribe iCloud KVS using the new key suffix.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var collection: ProfileCollection

    /// Concrete on-disk URL for the profiles manifest.
    let profilesURL: URL
    /// Directory holding per-profile records JSON files.
    let recordsDirectory: URL
    /// Legacy single-file records URL. Migrated to the default profile on bootstrap.
    let legacyRecordsURL: URL

    var activeProfile: LocationProfile { collection.activeProfile }

    init(
        profilesURL: URL? = nil,
        recordsDirectory: URL? = nil,
        legacyRecordsURL: URL? = nil
    ) {
        let base = Self.applicationSupportRoot()
        self.profilesURL = profilesURL ?? base.appendingPathComponent("profiles.json")
        self.recordsDirectory = recordsDirectory ?? base.appendingPathComponent("records", isDirectory: true)
        self.legacyRecordsURL = legacyRecordsURL ?? base.appendingPathComponent("records.json")

        try? FileManager.default.createDirectory(at: self.recordsDirectory, withIntermediateDirectories: true)

        if let loaded = Self.loadProfiles(from: self.profilesURL) {
            self.collection = loaded
        } else {
            self.collection = ProfileCollection.bootstrap()
            Self.persist(self.collection, to: self.profilesURL)
            migrateLegacyRecordsIfPresent()
        }
    }

    /// On-disk records URL for the given profile.
    func recordsURL(for profile: LocationProfile) -> URL {
        recordsDirectory.appendingPathComponent("\(profile.id.uuidString).json")
    }

    func recordsURLForActiveProfile() -> URL {
        recordsURL(for: activeProfile)
    }

    /// KVS key suffix used by `iCloudSyncManager` so each profile syncs into
    /// its own namespace.
    func kvsKeySuffix(for profile: LocationProfile) -> String {
        profile.id.uuidString
    }

    // MARK: - Mutations

    func add(_ profile: LocationProfile, activate: Bool = true) {
        guard !collection.profiles.contains(where: { $0.id == profile.id }) else { return }
        var next = collection
        next.profiles.append(profile)
        if activate {
            next.activeProfileId = profile.id
        }
        collection = next
        persist()
    }

    func update(_ profile: LocationProfile) {
        guard let idx = collection.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var next = collection
        next.profiles[idx] = profile
        collection = next
        persist()
    }

    func remove(_ id: UUID) -> Bool {
        guard collection.profiles.count > 1 else { return false } // keep at least one
        var next = collection
        next.profiles.removeAll { $0.id == id }
        if next.activeProfileId == id {
            next.activeProfileId = next.profiles.first!.id
        }
        collection = next
        persist()

        // Best-effort cleanup of the records file.
        let url = recordsDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
        return true
    }

    func setActive(_ id: UUID) {
        guard collection.profiles.contains(where: { $0.id == id }) else { return }
        guard collection.activeProfileId != id else { return }
        var next = collection
        next.activeProfileId = id
        collection = next
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        Self.persist(collection, to: profilesURL)
    }

    private static func persist(_ collection: ProfileCollection, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(collection)
            try data.write(to: url, options: .atomic)
        } catch {
            // Persistence errors surface elsewhere — keep this best-effort.
        }
    }

    private static func loadProfiles(from url: URL) -> ProfileCollection? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ProfileCollection.self, from: data)
    }

    /// Older builds stored everything in a single `records.json`. Move it to the
    /// default profile's records URL and delete the original.
    private func migrateLegacyRecordsIfPresent() {
        let target = recordsURL(for: collection.activeProfile)
        guard FileManager.default.fileExists(atPath: legacyRecordsURL.path),
              !FileManager.default.fileExists(atPath: target.path) else { return }
        do {
            try FileManager.default.moveItem(at: legacyRecordsURL, to: target)
        } catch {
            // Fall back to copy + leave original untouched if move fails.
            try? FileManager.default.copyItem(at: legacyRecordsURL, to: target)
        }
    }

    static func applicationSupportRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("HengqinTracker", isDirectory: true)
    }
}
