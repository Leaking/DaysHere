import HengqinCore
import SwiftUI

struct HeatmapExportView: View {
    let snapshot: HeatmapSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("一年几天 · 2026 全年热力图")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                Text("截至 \(snapshot.today.rawValue)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            StatsSummary(stats: snapshot.stats)

            YearHeatmapView(
                records: snapshot.records,
                stats: snapshot.stats,
                today: snapshot.today,
                theme: snapshot.theme,
                cellSize: 13,
                gap: 3,
                scrollable: false
            )

            LegendView(theme: snapshot.theme)
        }
        .padding(26)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct StatsSummary: View {
    let stats: YearStats

    var body: some View {
        HStack(spacing: 18) {
            summary("自然日", stats.naturalDays, 183, .green)
            summary("工作日", stats.workdays, 124, .blue)
        }
    }

    private func summary(_ title: String, _ value: Int, _ target: Int, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text("/ \(target)")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
