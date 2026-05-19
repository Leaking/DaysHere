import HengqinCore

/// Builds the human-readable tooltip text shown when hovering over a day
/// cell in either the year or month heatmap.
///
/// Output is multi-line so macOS renders it as a richer popover tooltip:
///
///     2026-05-19 周二
///     在横琴 · GPS 检测
///     法定假日 · 调休上班
///
enum DayTooltipFormatter {
    static func text(
        for date: DateKey,
        kind: HeatmapKind,
        record: DayRecord?,
        calendar: HolidayCalendar2026
    ) -> String {
        var lines: [String] = []
        lines.append("\(date.rawValue) \(weekdayName(date))")
        lines.append(statusLine(kind: kind, record: record))

        if let calendarNote = calendarAnnotation(for: date, calendar: calendar) {
            lines.append(calendarNote)
        }

        return lines.joined(separator: "\n")
    }

    private static func statusLine(kind: HeatmapKind, record: DayRecord?) -> String {
        switch kind {
        case .gps:
            return "在横琴 · GPS 检测"
        case .manual:
            return "在横琴 · 手动标记"
        case .leave:
            return "请假桥接"
        case .bridge:
            return "假期桥接"
        case .absent:
            if record?.isLeave == true {
                return "标记为请假（未触发桥接）"
            }
            if record?.inHengqin == true {
                return "非工作日 GPS 命中（不计入）"
            }
            return "未计入"
        case .future:
            return "未来日期"
        }
    }

    private static func calendarAnnotation(for date: DateKey, calendar: HolidayCalendar2026) -> String? {
        if calendar.isHoliday(date) {
            return "法定假日"
        }
        if calendar.workdayOverrides.contains(date) {
            return "调休上班日"
        }
        return nil
    }

    static func weekdayName(_ date: DateKey) -> String {
        // DateKey.weekday returns 1=Sunday ... 7=Saturday (Cocoa convention).
        let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let idx = date.weekday
        guard idx >= 1, idx <= 7 else { return "" }
        return names[idx]
    }
}
