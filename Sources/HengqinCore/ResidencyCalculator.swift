public struct DayRecord: Codable, Equatable, Sendable {
    public var inHengqin: Bool
    public var isLeave: Bool
    public var manualHengqin: Bool

    public init(inHengqin: Bool, isLeave: Bool, manualHengqin: Bool) {
        self.inHengqin = inHengqin
        self.isLeave = isLeave
        self.manualHengqin = manualHengqin
    }
}

public enum DayStatus: Equatable, Sendable {
    case hengqin
    case bridged
    case none
}

public enum HeatmapKind: String, CaseIterable, Equatable, Sendable {
    case gps
    case manual
    case leave
    case bridge
    case absent
    case future
}

public struct YearStats: Equatable, Sendable {
    public var naturalDays: Int
    public var workdays: Int
    public var bridgedDays: Set<DateKey>

    public init(naturalDays: Int, workdays: Int, bridgedDays: Set<DateKey>) {
        self.naturalDays = naturalDays
        self.workdays = workdays
        self.bridgedDays = bridgedDays
    }
}

public struct ResidencyCalculator: Sendable {
    public let calendar: HolidayCalendar2026
    public let year: Int

    public init(calendar: HolidayCalendar2026, year: Int = 2026) {
        self.calendar = calendar
        self.year = year
    }

    public func calculateBridgedDays(records: [DateKey: DayRecord]) -> Set<DateKey> {
        var bridgedDays = Set<DateKey>()
        var gapBlock: [DateKey] = []

        func isBridgeAnchor(_ date: DateKey) -> Bool {
            guard let record = records[date] else { return false }
            return calendar.isWorkday(date) && record.inHengqin
        }

        func flushGap() {
            guard let first = gapBlock.first, let last = gapBlock.last else { return }
            let before = first.addingDays(-1)
            let after = last.addingDays(1)
            if isBridgeAnchor(before), isBridgeAnchor(after) {
                bridgedDays.formUnion(gapBlock)
            }
            gapBlock.removeAll()
        }

        for date in DateKey.allDates(in: year) {
            let record = records[date]
            if isBridgeAnchor(date) {
                flushGap()
            } else {
                let bridgeable = !calendar.isWorkday(date) || (record?.isLeave == true)
                if bridgeable {
                    gapBlock.append(date)
                } else {
                    flushGap()
                }
            }
        }
        flushGap()

        return bridgedDays
    }

    public func dayStatus(for date: DateKey, records: [DateKey: DayRecord], bridgedDays: Set<DateKey>) -> DayStatus {
        let record = records[date]
        if calendar.isWorkday(date) {
            if record?.inHengqin == true {
                return .hengqin
            }
            if bridgedDays.contains(date) {
                return .bridged
            }
        } else {
            if record?.manualHengqin == true {
                return .hengqin
            }
            if bridgedDays.contains(date) {
                return .bridged
            }
        }
        return .none
    }

    public func heatmapKind(
        for date: DateKey,
        records: [DateKey: DayRecord],
        bridgedDays: Set<DateKey>,
        today: DateKey
    ) -> HeatmapKind {
        if date > today {
            return .future
        }

        let record = records[date]
        switch dayStatus(for: date, records: records, bridgedDays: bridgedDays) {
        case .hengqin:
            return record?.manualHengqin == true ? .manual : .gps
        case .bridged:
            return record?.isLeave == true ? .leave : .bridge
        case .none:
            return .absent
        }
    }

    public struct MonthStats: Equatable, Sendable {
        public let naturalDays: Int
        public let workdays: Int

        public init(naturalDays: Int, workdays: Int) {
            self.naturalDays = naturalDays
            self.workdays = workdays
        }
    }

    public func monthStats(
        for month: Int,
        records: [DateKey: DayRecord],
        bridgedDays: Set<DateKey>
    ) -> MonthStats {
        var naturalDays = 0
        var workdays = 0
        for date in DateKey.allDates(in: year) where date.month == month {
            let status = dayStatus(for: date, records: records, bridgedDays: bridgedDays)
            if status != .none {
                naturalDays += 1
                if calendar.isWorkday(date) {
                    workdays += 1
                }
            }
        }
        return MonthStats(naturalDays: naturalDays, workdays: workdays)
    }

    public func yearStats(records: [DateKey: DayRecord]) -> YearStats {
        let bridged = calculateBridgedDays(records: records)
        var naturalDays = 0
        var workdays = 0

        for date in DateKey.allDates(in: year) {
            let status = dayStatus(for: date, records: records, bridgedDays: bridged)
            if status != .none {
                naturalDays += 1
                if calendar.isWorkday(date) {
                    workdays += 1
                }
            }
        }

        return YearStats(naturalDays: naturalDays, workdays: workdays, bridgedDays: bridged)
    }
}
