import Foundation

/// Backup format compatible with the Chrome extension. Shape:
/// ```json
/// {
///   "version": 1,
///   "exportDate": "2026-05-19T17:12:09.360Z",
///   "data": {
///     "day_2026-01-01": { "inHengqin": true, "isLeave": false, "manualHengqin": true },
///     ...
///   }
/// }
/// ```
public struct DataBackup: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let dayKeyPrefix = "day_"

    public let version: Int
    public let exportDate: String
    public let data: [String: DayRecord]

    public init(version: Int = DataBackup.currentVersion, exportDate: String, data: [String: DayRecord]) {
        self.version = version
        self.exportDate = exportDate
        self.data = data
    }

    public init(records: [DateKey: DayRecord], exportDate: Date = Date()) {
        var payload: [String: DayRecord] = [:]
        payload.reserveCapacity(records.count)
        for (date, record) in records {
            payload["\(DataBackup.dayKeyPrefix)\(date.rawValue)"] = record
        }
        self.version = DataBackup.currentVersion
        self.exportDate = DataBackup.makeISOFormatter().string(from: exportDate)
        self.data = payload
    }

    public var records: [DateKey: DayRecord] {
        var result: [DateKey: DayRecord] = [:]
        result.reserveCapacity(data.count)
        for (key, value) in data {
            guard key.hasPrefix(DataBackup.dayKeyPrefix) else { continue }
            let dateString = String(key.dropFirst(DataBackup.dayKeyPrefix.count))
            guard Self.isPlausibleDateString(dateString) else { continue }
            result[DateKey(dateString)] = value
        }
        return result
    }

    public static func encode(records: [DateKey: DayRecord], exportDate: Date = Date()) throws -> Data {
        let backup = DataBackup(records: records, exportDate: exportDate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    public static func decode(_ data: Data) throws -> DataBackup {
        try JSONDecoder().decode(DataBackup.self, from: data)
    }

    private static func isPlausibleDateString(_ string: String) -> Bool {
        // Quick shape check: YYYY-MM-DD
        guard string.count == 10 else { return false }
        let parts = string.split(separator: "-")
        guard parts.count == 3 else { return false }
        return parts[0].count == 4 && parts[1].count == 2 && parts[2].count == 2
            && parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
