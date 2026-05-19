import HengqinCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var store: ResidencyStore

    private var selectedDate: DateKey {
        store.selectedDate ?? store.today
    }

    var body: some View {
        ZStack {
            store.theme.background
                .opacity(0.40)
                .ignoresSafeArea()

            LiquidGlassContainer {
                VStack(alignment: .leading, spacing: 10) {
                    HeaderView(
                        today: store.today,
                        inHengqin: store.heatmapKind(for: store.today) == .gps || store.heatmapKind(for: store.today) == .manual,
                        viewMode: $store.viewMode,
                        theme: $store.theme
                    )

                    CompactStatsView(stats: store.stats, today: store.today)

                    heatmapContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(height: 202, alignment: .topLeading)
                        .clipped()

                    FooterView(
                        theme: store.theme,
                        selectedDate: selectedDate,
                        selectedRecord: store.record(for: selectedDate),
                        selectedKind: store.heatmapKind(for: selectedDate),
                        exportMessage: store.exportMessage
                    ) {
                        store.exportHeatmapImage()
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .liquidPanel(cornerRadius: 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
        }
    }

    @ViewBuilder
    private var heatmapContent: some View {
        if store.viewMode == .year {
            YearHeatmapView(
                records: store.records,
                stats: store.stats,
                today: store.today,
                theme: store.theme,
                selectedDate: store.selectedDate,
                onSelect: { store.select($0) },
                onAction: { date, action in store.apply(action, to: date) },
                cellSize: 10,
                gap: 2
            )
        } else {
            MonthHeatmapView(
                records: store.records,
                stats: store.stats,
                today: store.today,
                month: store.visibleMonth,
                theme: store.theme,
                selectedDate: store.selectedDate,
                onSelect: { store.select($0) },
                onAction: { date, action in store.apply(action, to: date) },
                onPreviousMonth: { store.showPreviousMonth() },
                onNextMonth: { store.showNextMonth() }
            )
        }
    }
}

private struct HeaderView: View {
    let today: DateKey
    let inHengqin: Bool
    @Binding var viewMode: HeatmapViewMode
    @Binding var theme: AppTheme

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [theme.accent, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: theme.accent.opacity(0.30), radius: 8, x: 0, y: 3)
                Text("横")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text("横琴驻留追踪")
                    .font(.system(size: 14, weight: .semibold))
                Text("2026 年度 · 截至 \(today.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $viewMode) {
                ForEach(HeatmapViewMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 108)
            .controlSize(.small)

            ThemeMenu(theme: $theme)

            HStack(spacing: 6) {
                Circle()
                    .fill(inHengqin ? .green : .secondary)
                    .frame(width: 7, height: 7)
                    .shadow(color: (inHengqin ? Color.green : Color.secondary).opacity(0.35), radius: 4)
                Text(inHengqin ? "在横琴" : "未在")
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .liquidControl(cornerRadius: 12)
        }
    }
}

private struct ThemeMenu: View {
    @Binding var theme: AppTheme

    var body: some View {
        Menu {
            ForEach(AppTheme.allCases) { item in
                Button {
                    theme = item
                } label: {
                    Label(item.title, systemImage: theme == item ? "checkmark" : "circle")
                }
            }
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 24)
        }
        .menuStyle(.button)
        .controlSize(.small)
        .help("换肤")
    }
}

private struct CompactStatsView: View {
    let stats: YearStats
    let today: DateKey

    var body: some View {
        HStack(spacing: 8) {
            CompactStatChip(
                title: "自然日",
                value: stats.naturalDays,
                target: 183,
                expected: expectedNaturalDays
            )

            CompactStatChip(
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

private struct CompactStatChip: View {
    let title: String
    let value: Int
    let target: Int
    let expected: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(value)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("/ \(target)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(paceText)
                    .font(.caption2.weight(.semibold))
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
                        .fill(.primary.opacity(0.38))
                        .frame(width: 1)
                        .offset(x: proxy.size.width * min(1, Double(expected) / Double(target)))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidControl(cornerRadius: 13)
    }

    private var diff: Int {
        value - expected
    }

    private var paceText: String {
        if diff > 0 { return "+\(diff)" }
        if diff < 0 { return "-\(abs(diff))" }
        return "持平"
    }

    private var paceColor: Color {
        diff < 0 ? .red : .green
    }
}

private struct FooterView: View {
    let theme: AppTheme
    let selectedDate: DateKey
    let selectedRecord: DayRecord?
    let selectedKind: HeatmapKind
    let exportMessage: String?
    let export: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CompactLegendView(theme: theme)

            Spacer()

            Text(exportMessage ?? "\(selectedDate.rawValue) · \(selectedStatusText)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if #available(macOS 26.0, *) {
                Button(action: export) {
                    Label("导出", systemImage: "square.and.arrow.down")
                }
                .controlSize(.small)
                .buttonStyle(.glassProminent)
            } else {
                Button(action: export) {
                    Label("导出", systemImage: "square.and.arrow.down")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var selectedStatusText: String {
        let base = HeatmapPalette.label(for: selectedKind)
        guard let selectedRecord else { return base }
        var flags: [String] = []
        if selectedRecord.inHengqin {
            flags.append(selectedRecord.manualHengqin ? "手动" : "GPS")
        }
        if selectedRecord.isLeave {
            flags.append("请假")
        }
        return flags.isEmpty ? base : "\(base) · \(flags.joined(separator: " / "))"
    }
}

private struct CompactLegendView: View {
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(HeatmapKind.allCases, id: \.self) { kind in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(HeatmapPalette.color(for: kind, theme: theme))
                        .frame(width: 9, height: 9)
                    Text(shortLabel(for: kind))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .help(HeatmapPalette.label(for: kind))
            }
        }
    }

    private func shortLabel(for kind: HeatmapKind) -> String {
        switch kind {
        case .gps: "GPS"
        case .manual: "手动"
        case .leave: "请假"
        case .bridge: "桥接"
        case .absent: "未计"
        case .future: "未来"
        }
    }
}
