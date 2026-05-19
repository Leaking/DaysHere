public struct MonthHeatmapLayout: Equatable, Sendable {
    public var weeks: [[DateKey?]]
    public var weekdayLabels: [String]

    public init(year: Int = 2026, month: Int, weekStart: WeekStart = .monday) {
        let dates = DateKey.allDates(in: year).filter { $0.month == month }
        guard let firstDate = dates.first, let lastDate = dates.last else {
            weeks = []
            weekdayLabels = Self.labels(for: weekStart)
            return
        }

        let startWeekday = weekStart == .sunday ? 1 : 2
        var current = firstDate
        while current.weekday != startWeekday {
            current = current.addingDays(-1)
        }

        var builtWeeks: [[DateKey?]] = []
        while current <= lastDate {
            var week: [DateKey?] = []
            for _ in 0..<7 {
                week.append(current.month == month ? current : nil)
                current = current.addingDays(1)
            }
            builtWeeks.append(week)
        }

        weeks = builtWeeks
        weekdayLabels = Self.labels(for: weekStart)
    }

    private static func labels(for weekStart: WeekStart) -> [String] {
        weekStart == .sunday
            ? ["日", "一", "二", "三", "四", "五", "六"]
            : ["一", "二", "三", "四", "五", "六", "日"]
    }
}
