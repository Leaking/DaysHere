import Foundation

public struct DateKey: RawRepresentable, Hashable, Codable, Comparable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(date: Date) {
        self.rawValue = Self.formatter.string(from: date)
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    public static func < (lhs: DateKey, rhs: DateKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var year: Int {
        Int(rawValue.prefix(4)) ?? 0
    }

    public var month: Int {
        Int(rawValue.dropFirst(5).prefix(2)) ?? 0
    }

    public var day: Int {
        Int(rawValue.suffix(2)) ?? 0
    }

    public var date: Date {
        var components = DateComponents()
        components.calendar = Self.calendar
        components.timeZone = Self.calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return Self.calendar.date(from: components)!
    }

    public var weekday: Int {
        Self.calendar.component(.weekday, from: date)
    }

    public func addingDays(_ days: Int) -> DateKey {
        let next = Self.calendar.date(byAdding: .day, value: days, to: date)!
        return DateKey(Self.formatter.string(from: next))
    }

    public static func allDates(in year: Int) -> [DateKey] {
        var result: [DateKey] = []
        var current = DateKey("\(year)-01-01")
        while current.year == year {
            result.append(current)
            current = current.addingDays(1)
        }
        return result
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
