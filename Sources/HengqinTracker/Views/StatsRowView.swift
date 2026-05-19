import HengqinCore
import SwiftUI

struct StatsRowView: View {
    let stats: YearStats
    let today: DateKey

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            StatBlock(
                title: "自然日",
                value: stats.naturalDays,
                target: 183,
                expected: expectedNaturalDays
            )

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: 56)
                .padding(.top, 2)

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

    private let aheadColor = Color(red: 0.184, green: 0.561, blue: 0.247) // #2F8F3F
    private let behindColor = Color(red: 0.851, green: 0.329, blue: 0.290) // #D9544A

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(value)")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-0.4)
                Text("/ \(target)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(paceText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(paceColor)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(paceColor)
                        .frame(width: proxy.size.width * min(1, Double(value) / Double(target)))
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 1.5)
                        .offset(x: proxy.size.width * min(1, Double(expected) / Double(target)) - 0.75)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var diff: Int { value - expected }

    private var paceText: String {
        if diff >= 1 { return "↑ 超前 \(diff) 天" }
        if diff <= -1 { return "↓ 落后 \(abs(diff)) 天" }
        return "持平"
    }

    private var paceColor: Color {
        if diff >= 1 { return aheadColor }
        if diff <= -1 { return behindColor }
        return .secondary
    }
}
