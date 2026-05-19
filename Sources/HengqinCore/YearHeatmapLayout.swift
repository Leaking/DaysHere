public enum WeekStart: Sendable {
    case monday
    case sunday
}

public struct MonthLabel: Equatable, Sendable {
    public var column: Int
    public var month: Int

    public init(column: Int, month: Int) {
        self.column = column
        self.month = month
    }
}

public struct YearHeatmapLayout: Equatable, Sendable {
    public var columns: [[DateKey?]]
    public var monthLabels: [MonthLabel]
    public var weekdayLabels: [String]

    public init(year: Int = 2026, weekStart: WeekStart = .monday) {
        var first = DateKey("\(year)-01-01")
        let startWeekday = weekStart == .sunday ? 1 : 2
        while first.weekday != startWeekday {
            first = first.addingDays(-1)
        }

        let end = DateKey("\(year)-12-31")
        var current = first
        var builtColumns: [[DateKey?]] = []

        while current <= end {
            var column: [DateKey?] = []
            for _ in 0..<7 {
                column.append(current.year == year ? current : nil)
                current = current.addingDays(1)
            }
            builtColumns.append(column)
        }

        var labels: [MonthLabel] = []
        var lastMonth = -1
        for (columnIndex, column) in builtColumns.enumerated() {
            guard let date = column.compactMap({ $0 }).first else { continue }
            if date.month != lastMonth {
                if labels.isEmpty || columnIndex - labels[labels.count - 1].column >= 3 {
                    labels.append(MonthLabel(column: columnIndex, month: date.month))
                }
                lastMonth = date.month
            }
        }

        columns = builtColumns
        monthLabels = labels
        weekdayLabels = weekStart == .sunday
            ? ["日", "", "二", "", "四", "", "六"]
            : ["一", "", "三", "", "五", "", "日"]
    }
}
