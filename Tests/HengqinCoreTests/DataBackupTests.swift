import XCTest
@testable import HengqinCore

final class DataBackupTests: XCTestCase {
    private let sampleRecords: [DateKey: DayRecord] = [
        DateKey("2026-01-01"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: true),
        DateKey("2026-02-11"): DayRecord(inHengqin: false, isLeave: true, manualHengqin: false),
        DateKey("2026-05-19"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false)
    ]

    func testEncodeProducesChromeCompatibleFormat() throws {
        let data = try DataBackup.encode(records: sampleRecords, exportDate: Date(timeIntervalSince1970: 1_779_209_982))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertNotNil(json["exportDate"] as? String)

        let payload = try XCTUnwrap(json["data"] as? [String: [String: Bool]])
        XCTAssertEqual(payload.count, 3)
        XCTAssertEqual(payload["day_2026-01-01"]?["inHengqin"], true)
        XCTAssertEqual(payload["day_2026-01-01"]?["manualHengqin"], true)
        XCTAssertEqual(payload["day_2026-02-11"]?["isLeave"], true)
        XCTAssertEqual(payload["day_2026-02-11"]?["inHengqin"], false)
    }

    func testDecodeRoundTripsRecords() throws {
        let encoded = try DataBackup.encode(records: sampleRecords)
        let backup = try DataBackup.decode(encoded)

        XCTAssertEqual(backup.version, 1)
        XCTAssertEqual(backup.records, sampleRecords)
    }

    func testDecodeAcceptsExampleBackup() throws {
        let json = """
        {
          "version": 1,
          "exportDate": "2026-05-19T17:12:09.360Z",
          "data": {
            "day_2026-01-01": { "inHengqin": true, "isLeave": false, "manualHengqin": true },
            "day_2026-02-11": { "inHengqin": false, "isLeave": true, "manualHengqin": false }
          }
        }
        """.data(using: .utf8)!

        let backup = try DataBackup.decode(json)
        XCTAssertEqual(backup.exportDate, "2026-05-19T17:12:09.360Z")
        XCTAssertEqual(backup.records.count, 2)
        XCTAssertEqual(backup.records[DateKey("2026-01-01")], DayRecord(inHengqin: true, isLeave: false, manualHengqin: true))
        XCTAssertEqual(backup.records[DateKey("2026-02-11")], DayRecord(inHengqin: false, isLeave: true, manualHengqin: false))
    }

    func testDecodeIgnoresUnknownKeys() throws {
        let json = """
        {
          "version": 1,
          "exportDate": "2026-05-19T17:12:09.360Z",
          "data": {
            "day_2026-01-01": { "inHengqin": true, "isLeave": false, "manualHengqin": true },
            "loc_2026-01-01": { "inHengqin": true, "isLeave": false, "manualHengqin": false }
          }
        }
        """.data(using: .utf8)!

        let backup = try DataBackup.decode(json)
        XCTAssertEqual(backup.records.count, 1)
        XCTAssertEqual(backup.records.keys.first, DateKey("2026-01-01"))
    }
}
