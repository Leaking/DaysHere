import Foundation

/// A user-defined location context. Each profile owns an independent set of
/// `DayRecord` entries — switching the active profile switches the visible
/// dataset and the iCloud KVS namespace.
///
/// The coordinates are informational on macOS today (the menu-bar app does not
/// itself capture GPS); they exist so the Chrome extension or a future
/// macOS background sampler can decide "am I currently inside profile X".
public struct LocationProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radiusKilometers: Double
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusKilometers: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusKilometers = radiusKilometers
        self.createdAt = createdAt
    }

    /// Built-in starting profile: Hengqin (横琴), 22.125°N, 113.535°E, 8 km radius.
    /// First launch of the app inserts this and migrates the legacy
    /// `records.json` into it.
    public static func hengqinDefault(createdAt: Date = Date()) -> LocationProfile {
        LocationProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "横琴",
            latitude: 22.125,
            longitude: 113.535,
            radiusKilometers: 8.0,
            createdAt: createdAt
        )
    }
}

/// On-disk envelope for the user's profile list and current selection.
/// Persisted at `Application Support/HengqinTracker/profiles.json`.
public struct ProfileCollection: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public var activeProfileId: UUID
    public var profiles: [LocationProfile]

    public init(activeProfileId: UUID, profiles: [LocationProfile], version: Int = ProfileCollection.currentVersion) {
        self.version = version
        self.activeProfileId = activeProfileId
        self.profiles = profiles
    }

    public func profile(with id: UUID) -> LocationProfile? {
        profiles.first(where: { $0.id == id })
    }

    public var activeProfile: LocationProfile {
        profile(with: activeProfileId) ?? profiles.first ?? LocationProfile.hengqinDefault()
    }

    public static func bootstrap() -> ProfileCollection {
        let defaultProfile = LocationProfile.hengqinDefault()
        return ProfileCollection(activeProfileId: defaultProfile.id, profiles: [defaultProfile])
    }
}
