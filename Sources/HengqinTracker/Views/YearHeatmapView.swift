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
    var cellSize: CGFloat = 14
    var gap: CGFloat = 3

    private let layout = YearHeatmapLayout(year: 2026, weekStart: .monday)
    private let calculator = ResidencyCalculator(calendar: HolidayCalendar2026())

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("全年热力图")
                    .font(.headline)
                Spacer()
                Text("自然日 \(stats.naturalDays) / 183 · 工作日 \(stats.workdays) / 124")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    monthLabels
                    weekdayLabels
                    cells
                }
                .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
                .padding(.vertical, 2)
            }
        }
    }

    private var monthLabelHeight: CGFloat { 22 }
    private var labelColumnWidth: CGFloat { 22 }
    private var cellOuter: CGFloat { cellSize + gap }
    private var totalWidth: CGFloat { labelColumnWidth + CGFloat(layout.columns.count) * cellOuter }
    private var totalHeight: CGFloat { monthLabelHeight + 7 * cellOuter }

    private var monthLabels: some View {
        ForEach(layout.monthLabels, id: \.month) { label in
            Text("\(label.month)月")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .position(
                    x: labelColumnWidth + CGFloat(label.column) * cellOuter + 10,
                    y: 8
                )
        }
    }

    private var weekdayLabels: some View {
        ForEach(Array(layout.weekdayLabels.enumerated()), id: \.offset) { row, label in
            if !label.isEmpty {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .position(
                        x: 6,
                        y: monthLabelHeight + CGFloat(row) * cellOuter + cellSize / 2
                    )
            }
        }
    }

    private var cells: some View {
        ForEach(Array(layout.columns.enumerated()), id: \.offset) { columnIndex, column in
            ForEach(Array(column.enumerated()), id: \.offset) { rowIndex, maybeDate in
                if let date = maybeDate {
                    let kind = calculator.heatmapKind(for: date, records: records, bridgedDays: stats.bridgedDays, today: today)
                    Button {
                        onSelect?(date)
                    } label: {
                        RoundedRectangle(cornerRadius: max(2, cellSize * 0.24), style: .continuous)
                            .fill(HeatmapPalette.color(for: kind, theme: theme))
                            .overlay(cellOutline(for: date))
                            .frame(width: cellSize, height: cellSize)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("标记在横琴") {
                            onAction?(date, .markInHengqin)
                        }
                        Button("标记请假") {
                            onAction?(date, .markLeave)
                        }
                        Divider()
                        Button("取消在横琴") {
                            onAction?(date, .unmarkInHengqin)
                        }
                        Button("取消请假") {
                            onAction?(date, .unmarkLeave)
                        }
                        Button("清除当天") {
                            onAction?(date, .clear)
                        }
                    }
                        .position(
                            x: labelColumnWidth + CGFloat(columnIndex) * cellOuter + cellSize / 2,
                            y: monthLabelHeight + CGFloat(rowIndex) * cellOuter + cellSize / 2
                        )
                        .help("\(date.rawValue) · \(HeatmapPalette.label(for: kind))")
                }
            }
        }
    }

    @ViewBuilder
    private func cellOutline(for date: DateKey) -> some View {
        ZStack {
            if date == today {
                RoundedRectangle(cornerRadius: max(3, cellSize * 0.3), style: .continuous)
                    .stroke(.primary, lineWidth: 1.4)
                    .padding(-2)
            }
            if date == selectedDate {
                RoundedRectangle(cornerRadius: max(3, cellSize * 0.3), style: .continuous)
                    .stroke(theme.accent, lineWidth: 2.2)
                    .padding(-3.5)
            }
        }
    }
}

struct LegendView: View {
    var theme: AppTheme = .sequoia

    var body: some View {
        HStack(spacing: 18) {
            ForEach(HeatmapKind.allCases, id: \.self) { kind in
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(HeatmapPalette.color(for: kind, theme: theme))
                        .frame(width: 11, height: 11)
                    Text(HeatmapPalette.label(for: kind))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
