import XCTest
@testable import HengqinCore

final class LocationProfileTests: XCTestCase {
    func testDefaultProfileIsHengqin() {
        let profile = LocationProfile.hengqinDefault()
        XCTAssertEqual(profile.name, "横琴")
        XCTAssertEqual(profile.latitude, 22.125, accuracy: 0.0001)
        XCTAssertEqual(profile.longitude, 113.535, accuracy: 0.0001)
        XCTAssertEqual(profile.radiusKilometers, 8.0, accuracy: 0.0001)
    }

    func testDefaultProfileIdIsStable() {
        // Same UUID across calls so legacy migration writes to a predictable
        // records file even after relaunching with a fresh ProfileStore.
        let a = LocationProfile.hengqinDefault()
        let b = LocationProfile.hengqinDefault()
        XCTAssertEqual(a.id, b.id)
    }

    func testProfileCollectionLookupAndActive() {
        let p1 = LocationProfile(name: "A", latitude: 1, longitude: 2, radiusKilometers: 5)
        let p2 = LocationProfile(name: "B", latitude: 3, longitude: 4, radiusKilometers: 10)
        let collection = ProfileCollection(activeProfileId: p2.id, profiles: [p1, p2])

        XCTAssertEqual(collection.activeProfile.id, p2.id)
        XCTAssertEqual(collection.profile(with: p1.id)?.name, "A")
        XCTAssertNil(collection.profile(with: UUID()))
    }

    func testBootstrapCreatesSingleDefault() {
        let collection = ProfileCollection.bootstrap()
        XCTAssertEqual(collection.profiles.count, 1)
        XCTAssertEqual(collection.activeProfileId, collection.profiles[0].id)
        XCTAssertEqual(collection.profiles[0].name, "横琴")
    }

    func testProfileCollectionCodableRoundTrip() throws {
        let profiles = [
            LocationProfile.hengqinDefault(),
            LocationProfile(name: "深圳", latitude: 22.55, longitude: 114.05, radiusKilometers: 20)
        ]
        let original = ProfileCollection(activeProfileId: profiles[1].id, profiles: profiles)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProfileCollection.self, from: data)

        XCTAssertEqual(decoded.activeProfileId, original.activeProfileId)
        XCTAssertEqual(decoded.profiles.map(\.name), ["横琴", "深圳"])
    }
}
