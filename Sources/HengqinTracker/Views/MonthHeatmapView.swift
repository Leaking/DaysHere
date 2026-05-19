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
    private var layout: MonthHeatmapLayout {
        MonthHeatmapLayout(year: 2026, month: month, weekStart: .monday)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(month) 月视图")
                    .font(.subheadline.weight(.semibold))

                Text(monthSummary)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onPreviousMonth?()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 14, height: 14)
                }
                .controlSize(.small)
                .disabled(month <= 1)
                .help("上个月")

                Button {
                    onNextMonth?()
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 14, height: 14)
                }
                .controlSize(.small)
                .disabled(month >= 12)
                .help("下个月")
            }

            HStack(spacing: columnGap) {
                ForEach(layout.weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: cellWidth)
                }
            }

            VStack(spacing: rowGap) {
                ForEach(Array(layout.weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: columnGap) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, maybeDate in
                            if let date = maybeDate {
                                dayCell(for: date)
                            } else {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.clear)
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }

    private var cellWidth: CGFloat { 76 }
    private var cellHeight: CGFloat { 25 }
    private var columnGap: CGFloat { 5 }
    private var rowGap: CGFloat { 4 }

    private var monthSummary: String {
        let dates = DateKey.allDates(in: 2026).filter { $0.month == month && $0 <= today }
        let counted = dates.filter {
            calculator.dayStatus(for: $0, records: records, bridgedDays: stats.bridgedDays) != .none
        }.count
        return "\(counted) 天已计入"
    }

    private func dayCell(for date: DateKey) -> some View {
        let kind = calculator.heatmapKind(for: date, records: records, bridgedDays: stats.bridgedDays, today: today)
        return Button {
            onSelect?(date)
        } label: {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HeatmapPalette.color(for: kind, theme: theme))
                .overlay(alignment: .leading) {
                    Text("\(date.day)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(foregroundStyle(for: kind))
                        .padding(.leading, 8)
                }
                .overlay(cellOutline(for: date))
                .frame(width: cellWidth, height: cellHeight)
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
        .help("\(date.rawValue) · \(HeatmapPalette.label(for: kind))")
    }

    private func foregroundStyle(for kind: HeatmapKind) -> Color {
        switch kind {
        case .gps, .manual:
            return .white
        default:
            return .primary
        }
    }

    @ViewBuilder
    private func cellOutline(for date: DateKey) -> some View {
        ZStack {
            if date == today {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.primary, lineWidth: 1.2)
                    .padding(-1.5)
            }
            if date == selectedDate {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.accent, lineWidth: 2)
                    .padding(-3)
            }
        }
    }
}
