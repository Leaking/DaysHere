public enum DemoDataFactory {
    public static let today = DateKey("2026-05-19")

    public static func makeRecords(calendar: HolidayCalendar2026 = HolidayCalendar2026()) -> [DateKey: DayRecord] {
        var rng = Mulberry32(seed: 20260119)
        var records: [DateKey: DayRecord] = [:]
        let awayBlocks: [(DateKey, DateKey)] = [
            ("2026-01-12", "2026-01-15"),
            ("2026-02-09", "2026-02-13"),
            ("2026-03-18", "2026-03-20"),
            ("2026-04-13", "2026-04-15")
        ]
        let leaveDays: Set<DateKey> = [
            "2026-02-13",
            "2026-02-24",
            "2026-04-03",
            "2026-04-07",
            "2026-04-30",
            "2026-05-06"
        ]

        func inAwayBlock(_ date: DateKey) -> Bool {
            awayBlocks.contains { start, end in date >= start && date <= end }
        }

        for date in DateKey.allDates(in: 2026) where date <= today {
            let isHoliday = calendar.isHoliday(date)
            let isWorkday = calendar.isWorkday(date)
            var record = DayRecord(inHengqin: false, isLeave: false, manualHengqin: false)

            if leaveDays.contains(date) {
                record.isLeave = true
            } else if isHoliday {
                // Let bridge rules decide holiday coverage.
            } else if isWorkday {
                if !inAwayBlock(date), rng.next() < 0.92 {
                    record.inHengqin = true
                    if rng.next() < 0.06 {
                        record.manualHengqin = true
                    }
                }
            } else if !inAwayBlock(date), rng.next() < 0.18 {
                record.inHengqin = true
                record.manualHengqin = true
            }

            if record.inHengqin || record.isLeave || record.manualHengqin {
                records[date] = record
            }
        }

        return records
    }
}

private struct Mulberry32 {
    private var seed: UInt32

    init(seed: UInt32) {
        self.seed = seed
    }

    mutating func next() -> Double {
        seed &+= 0x6D2B79F5
        var t = seed
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double((t ^ (t >> 14))) / 4_294_967_296.0
    }
}
