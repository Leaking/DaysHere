import HengqinCore
import SwiftUI

struct StatsRowView: View {
    let stats: YearStats
    let today: DateKey

    var body: some View {
        HStack(spacing: 28) {
            StatBlock(
                title: "自然日",
                value: stats.naturalDays,
                target: 183,
                expected: expectedNaturalDays
            )

            Rectangle()
                .fill(.separator.opacity(0.5))
                .frame(width: 1, height: 54)

            StatBlock(
                title: "工作日",
                value: stats.workdays,
                target: 124,
                expected: expectedWorkdays
            )
        }
    }

    private var dayOfYear: Int {
        DateKey.allDates(in: 2026).prefix { $0 <= today }.count
    }

    private var expectedNaturalDays: Int {
        Int((Double(dayOfYear) / 365.0 * 183.0).rounded())
    }

    private var expectedWorkdays: Int {
        let calendar = HolidayCalendar2026()
        let all = DateKey.allDates(in: 2026)
        let elapsed = all.prefix { $0 <= today }.filter(calendar.isWorkday).count
        let total = all.filter(calendar.isWorkday).count
        return Int((Double(elapsed) / Double(total) * 124.0).rounded())
    }
}

private struct StatBlock: View {
    let title: String
    let value: Int
    let target: Int
    let expected: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(value)")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("/ \(target)")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(paceText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(paceColor)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.12))
                    Capsule()
                        .fill(paceColor)
                        .frame(width: proxy.size.width * min(1, Double(value) / Double(target)))
                    Rectangle()
                        .fill(.primary.opacity(0.45))
                        .frame(width: 1.5)
                        .offset(x: proxy.size.width * min(1, Double(expected) / Double(target)))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var diff: Int {
        value - expected
    }

    private var paceText: String {
        if diff > 0 { return "超前 \(diff) 天" }
        if diff < 0 { return "落后 \(abs(diff)) 天" }
        return "持平"
    }

    private var paceColor: Color {
        diff < 0 ? .red : .green
    }
}
