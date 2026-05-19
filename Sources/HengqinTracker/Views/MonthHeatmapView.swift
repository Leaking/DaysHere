import HengqinCore
import SwiftUI

struct MonthHeatmapView: View {
    let records: [DateKey: DayRecord]
    let stats: YearStats
    let today: DateKey
    let month: Int
    var theme: AppTheme = .sequoia
    var selectedDate: DateKey?
    var onSelect: ((DateKey) -> Void)?
    var onAction: ((DateKey, DayRecordAction) -> Void)?
    var onPreviousMonth: (() -> Void)?
    var onNextMonth: (() -> Void)?

    private let calculator = ResidencyCalculator(calendar: HolidayCalendar2026())
    private let holidayCalendar = HolidayCalendar2026()

    @State private var hoveredDate: DateKey?
    private var layout: MonthHeatmapLayout {
        MonthHeatmapLayout(year: 2026, month: month, weekStart: .monday)
    }

    /// Trim trailing weeks that have no in-month days so we don't reserve a
    /// 6th row when June (5 rows) only needs 5.
    private var visibleWeeks: [[DateKey?]] {
        var weeks = layout.weeks
        while let last = weeks.last, last.allSatisfy({ $0 == nil }) {
            weeks.removeLast()
        }
        return weeks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            monthHeader
            weekdayRow
            gridView
        }
    }

    // MARK: - Header / weekday row

    private var monthHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("2026 年 \(month) 月")
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.1)
            Text(monthSummary)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Spacer()
            navButton(systemName: "chevron.left", action: { onPreviousMonth?() }, disabled: month <= 1)
            navButton(systemName: "chevron.right", action: { onNextMonth?() }, disabled: month >= 12)
        }
    }

    private var weekdayRow: some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                ForEach(layout.weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: (proxy.size.width - 3 * 6) / 7, alignment: .center)
                }
            }
        }
        .frame(height: 11)
    }

    // MARK: - Grid (responsive)

    private var gridView: some View {
        GeometryReader { geo in
            let rows = max(1, visibleWeeks.count)
            let cellW = (geo.size.width - 3 * 6) / 7
            let cellH = max(14, (geo.size.height - CGFloat(rows - 1) * 3) / CGFloat(rows))

            VStack(spacing: 3) {
                ForEach(Array(visibleWeeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 3) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, maybeDate in
                            if let date = maybeDate {
                                dayCell(for: date)
                                    .frame(width: cellW, height: cellH)
                            } else {
                                Color.clear
                                    .frame(width: cellW, height: cellH)
                            }
                        }
                    }
                }
            }
        }
    }

    private var monthSummary: String {
        let monthStats = calculator.monthStats(for: month, records: records, bridgedDays: stats.bridgedDays)
        return "\(monthStats.naturalDays) 自然日 · \(monthStats.workdays) 工作日"
    }

    private func navButton(systemName: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.3) : Color.secondary)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Day cell (inline, single row — no bottom dots)

    private func dayCell(for date: DateKey) -> some View {
        let kind = calculator.heatmapKind(for: date, records: records, bridgedDays: stats.bridgedDays, today: today)
        let isToday = date == today
        let isFuture = date > today
        let isFilled = !isFuture && kind != .absent
        let isHoliday = holidayCalendar.isHoliday(date)
        let isWorkdayOverride = holidayCalendar.workdayOverrides.contains(date)
        let isHovered = hoveredDate == date

        let dayNumberColor: Color = isFilled ? HeatmapPalette.textColor(for: kind) : Color.primary.opacity(0.85)
        let badgeColor: Color = isFilled ? HeatmapPalette.subtleForeground(for: kind) : .secondary
        let tooltip = DayTooltipFormatter.text(
            for: date,
            kind: kind,
            record: records[date],
            calendar: holidayCalendar
        )

        return Button {
            onSelect?(date)
        } label: {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(HeatmapPalette.color(for: kind, theme: theme))
                .overlay(
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(date.day)")
                            .font(.system(size: 11, weight: isToday ? .bold : .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(dayNumberColor)
                        Spacer(minLength: 0)
                        if isHoliday {
                            Text("休")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(badgeColor)
                        } else if isWorkdayOverride {
                            Text("班")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(badgeColor)
                        }
                    }
                    .padding(.horizontal, 5)
                )
                .overlay(cellOutline(isToday: isToday, isSelected: date == selectedDate))
                .overlay(hoverOverlay(visible: isHovered))
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenu(for: date) }
        .onHover { hovering in
            hoveredDate = hovering ? date : (hoveredDate == date ? nil : hoveredDate)
        }
        .help(tooltip)
    }

    @ViewBuilder
    private func hoverOverlay(visible: Bool) -> some View {
        if visible {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.accent.opacity(0.85), lineWidth: 1.2)
        }
    }

    @ViewBuilder
    private func contextMenu(for date: DateKey) -> some View {
        Button("标记在横琴") { onAction?(date, .markInHengqin) }
        Button("标记请假") { onAction?(date, .markLeave) }
        Divider()
        Button("取消在横琴") { onAction?(date, .unmarkInHengqin) }
        Button("取消请假") { onAction?(date, .unmarkLeave) }
        Button("清除当天") { onAction?(date, .clear) }
    }

    @ViewBuilder
    private func cellOutline(isToday: Bool, isSelected: Bool) -> some View {
        ZStack {
            if isToday {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.85), lineWidth: 1.2)
            }
            if isSelected, !isToday {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.accent, lineWidth: 1.4)
            }
        }
    }
}
