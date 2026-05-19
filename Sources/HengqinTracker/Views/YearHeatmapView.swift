import HengqinCore
import SwiftUI

struct YearHeatmapView: View {
    let records: [DateKey: DayRecord]
    let stats: YearStats
    let today: DateKey
    var theme: AppTheme = .sequoia
    var selectedDate: DateKey?
    var onSelect: ((DateKey) -> Void)?
    var onAction: ((DateKey, DayRecordAction) -> Void)?
    var cellSize: CGFloat = 9
    var gap: CGFloat = 2
    /// Set to false when rendering through `ImageRenderer` — ScrollView
    /// content collapses to 0 inside ImageRenderer, dropping the heatmap.
    var scrollable: Bool = true

    private let layout = YearHeatmapLayout(year: 2026, weekStart: .monday)
    private let calculator = ResidencyCalculator(calendar: HolidayCalendar2026())

    @State private var pulse = false
    @State private var hoveredDate: DateKey?

    var body: some View {
        Group {
            if scrollable {
                ScrollView(.horizontal, showsIndicators: false) {
                    heatmapContent
                }
            } else {
                heatmapContent
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }

    private var heatmapContent: some View {
        ZStack(alignment: .topLeading) {
            monthLabels
            weekdayLabels
            cells
        }
        .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
    }

    private var monthLabelHeight: CGFloat { 16 }
    private var labelColumnWidth: CGFloat { 16 }
    private var cellOuter: CGFloat { cellSize + gap }
    private var totalWidth: CGFloat { labelColumnWidth + CGFloat(layout.columns.count) * cellOuter }
    private var totalHeight: CGFloat { monthLabelHeight + 7 * cellOuter }

    private var monthLabels: some View {
        ForEach(layout.monthLabels, id: \.month) { label in
            Text("\(label.month)月")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(-0.05)
                .position(
                    x: labelColumnWidth + CGFloat(label.column) * cellOuter + 8,
                    y: 7
                )
        }
    }

    private var weekdayLabels: some View {
        ForEach(Array(layout.weekdayLabels.enumerated()), id: \.offset) { row, label in
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .position(
                        x: 5,
                        y: monthLabelHeight + CGFloat(row) * cellOuter + cellSize / 2
                    )
            }
        }
    }

    private var cells: some View {
        ForEach(Array(layout.columns.enumerated()), id: \.offset) { columnIndex, column in
            ForEach(Array(column.enumerated()), id: \.offset) { rowIndex, maybeDate in
                if let date = maybeDate {
                    cellView(date: date, columnIndex: columnIndex, rowIndex: rowIndex)
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(date: DateKey, columnIndex: Int, rowIndex: Int) -> some View {
        let kind = calculator.heatmapKind(for: date, records: records, bridgedDays: stats.bridgedDays, today: today)
        let isToday = date == today
        let isHovered = hoveredDate == date
        let radius = max(2, cellSize * 0.22)
        let tooltip = DayTooltipFormatter.text(
            for: date,
            kind: kind,
            record: records[date],
            calendar: HolidayCalendar2026()
        )
        Button {
            onSelect?(date)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(HeatmapPalette.color(for: kind, theme: theme))
                    .frame(width: cellSize, height: cellSize)

                if isToday {
                    RoundedRectangle(cornerRadius: radius + 1.5, style: .continuous)
                        .stroke(Color.primary.opacity(0.9), lineWidth: 1.2)
                        .frame(width: cellSize + 3, height: cellSize + 3)

                    RoundedRectangle(cornerRadius: radius + 1.5, style: .continuous)
                        .stroke(Color.primary.opacity(0.45), lineWidth: 1.2)
                        .frame(width: cellSize + 3, height: cellSize + 3)
                        .scaleEffect(pulse ? 1.5 : 1)
                        .opacity(pulse ? 0 : 0.5)
                }

                if date == selectedDate, !isToday {
                    RoundedRectangle(cornerRadius: radius + 1.5, style: .continuous)
                        .stroke(theme.accent, lineWidth: 1.5)
                        .frame(width: cellSize + 3, height: cellSize + 3)
                }

                // Hover ring — same theme.accent treatment as MonthHeatmapView
                // for consistency. No scaling / shadow (which earlier read as
                // a white halo on lighter cells).
                if isHovered {
                    RoundedRectangle(cornerRadius: radius + 1.5, style: .continuous)
                        .stroke(theme.accent.opacity(0.85), lineWidth: 1.2)
                        .frame(width: cellSize + 3, height: cellSize + 3)
                }
            }
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .contextMenu { heatmapContextMenu(for: date) }
        .onHover { hovering in
            hoveredDate = hovering ? date : (hoveredDate == date ? nil : hoveredDate)
        }
        .position(
            x: labelColumnWidth + CGFloat(columnIndex) * cellOuter + cellSize / 2,
            y: monthLabelHeight + CGFloat(rowIndex) * cellOuter + cellSize / 2
        )
        .help(tooltip)
    }

    @ViewBuilder
    private func heatmapContextMenu(for date: DateKey) -> some View {
        Button("标记在横琴") { onAction?(date, .markInHengqin) }
        Button("标记请假") { onAction?(date, .markLeave) }
        Divider()
        Button("取消在横琴") { onAction?(date, .unmarkInHengqin) }
        Button("取消请假") { onAction?(date, .unmarkLeave) }
        Button("清除当天") { onAction?(date, .clear) }
    }

}

struct LegendView: View {
    var theme: AppTheme = .sequoia

    var body: some View {
        HStack(spacing: 14) {
            ForEach(HeatmapKind.allCases, id: \.self) { kind in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(HeatmapPalette.color(for: kind, theme: theme))
                        .frame(width: 10, height: 10)
                    Text(HeatmapPalette.label(for: kind))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
