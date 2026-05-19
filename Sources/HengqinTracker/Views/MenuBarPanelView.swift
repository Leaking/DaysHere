import HengqinCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var store: ResidencyStore
    var openSettings: () -> Void = {}

    private var selectedDate: DateKey {
        store.selectedDate ?? store.today
    }

    private var inHengqinNow: Bool {
        let kind = store.heatmapKind(for: store.today)
        return kind == .gps || kind == .manual
    }

    var body: some View {
        ZStack {
            // Single, unified background tint — the same color extends edge-to-edge
            // so the popover doesn't show a darker "ring" around the inner panel.
            store.theme.background
                .opacity(0.42)
                .ignoresSafeArea()

            LiquidGlassContainer {
                VStack(alignment: .leading, spacing: 12) {
                    PanelHeader(
                        today: store.today,
                        profileName: store.activeProfile.name,
                        inHengqin: inHengqinNow,
                        theme: $store.theme
                    )

                    StatsRowView(stats: store.stats, today: store.today)

                    ViewToggleDivider(viewMode: $store.viewMode)

                    heatmapBody
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    Spacer(minLength: 0)

                    PanelFooter(
                        theme: store.theme,
                        selectedDate: selectedDate,
                        selectedRecord: store.record(for: selectedDate),
                        selectedKind: store.heatmapKind(for: selectedDate),
                        exportMessage: store.exportMessage,
                        onShare: { store.copyDashboardImage() },
                        onOpenSettings: openSettings
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // No liquidPanel + no inner padding(8): the popover's own chrome
                // is the only outer border; the inner content uses the unified
                // theme tint directly without a second material layer that would
                // look like a "frame within a frame".
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private static let heatmapBodyHeight: CGFloat = 150

    @ViewBuilder
    private var heatmapBody: some View {
        if store.viewMode == .year {
            YearHeatmapView(
                records: store.records,
                stats: store.stats,
                today: store.today,
                theme: store.theme,
                selectedDate: store.selectedDate,
                onSelect: { store.select($0) },
                onAction: { date, action in store.apply(action, to: date) }
            )
            .frame(height: Self.heatmapBodyHeight, alignment: .topLeading)
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
            .frame(height: Self.heatmapBodyHeight, alignment: .topLeading)
        }
    }
}

// MARK: - Header

private struct PanelHeader: View {
    let today: DateKey
    let profileName: String
    let inHengqin: Bool
    @Binding var theme: AppTheme

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.239, green: 0.753, blue: 0.478),
                            Color(red: 0.122, green: 0.478, blue: 0.298)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: Color(red: 0.122, green: 0.478, blue: 0.298).opacity(0.30), radius: 6, x: 0, y: 2)
                Text("横")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
                    .blendMode(.overlay)
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(profileName)
                    .font(.system(size: 13.5, weight: .semibold))
                    .tracking(-0.1)
                    .lineLimit(1)
                Text("一年几天 · 2026 年度 · 截至 \(today.rawValue)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            StatusPill(inHengqin: inHengqin)

            ThemeSwatchRow(theme: $theme)
        }
    }
}

private struct ThemeSwatchRow: View {
    @Binding var theme: AppTheme

    var body: some View {
        HStack(spacing: 5) {
            ForEach(AppTheme.allCases) { item in
                ThemeSwatch(item: item, active: theme == item) {
                    withAnimation(.easeOut(duration: 0.15)) { theme = item }
                }
                .help(item.title)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.primary.opacity(0.05))
        )
    }
}

private struct ThemeSwatch: View {
    let item: AppTheme
    let active: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(item.background)
                    .frame(width: active ? 14 : 12, height: active ? 14 : 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                    )
                if active {
                    Circle()
                        .stroke(Color.primary.opacity(0.85), lineWidth: 1.4)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct StatusPill: View {
    let inHengqin: Bool

    var body: some View {
        let dot = inHengqin
            ? Color(red: 0.184, green: 0.561, blue: 0.247)
            : Color(nsColor: .secondaryLabelColor)
        HStack(spacing: 5) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(dot.opacity(0.18), lineWidth: 3).blur(radius: 0.5))
            Text(inHengqin ? "当前在横琴" : "当前不在横琴")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(-0.05)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}


// MARK: - View toggle divider

private struct ViewToggleDivider: View {
    @Binding var viewMode: HeatmapViewMode

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            HStack(spacing: 10) {
                SegmentedToggle(viewMode: $viewMode)
                Text(viewMode == .year ? "12 个月概览" : "逐日详情")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

private struct SegmentedToggle: View {
    @Binding var viewMode: HeatmapViewMode

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(.year, label: "全年")
            segmentButton(.month, label: "本月")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func segmentButton(_ value: HeatmapViewMode, label: String) -> some View {
        let active = viewMode == value
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { viewMode = value }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: active ? .semibold : .medium))
                .tracking(-0.05)
                .padding(.horizontal, 11)
                .padding(.vertical, 3)
                .frame(minWidth: 38)
                .foregroundStyle(active ? Color.primary : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(active ? Color(nsColor: .windowBackgroundColor).opacity(0.95) : Color.clear)
                        .shadow(color: Color.black.opacity(active ? 0.08 : 0), radius: active ? 1.5 : 0, x: 0, y: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Footer

private struct PanelFooter: View {
    let theme: AppTheme
    let selectedDate: DateKey
    let selectedRecord: DayRecord?
    let selectedKind: HeatmapKind
    let exportMessage: String?
    let onShare: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            HStack(alignment: .center, spacing: 10) {
                FooterLegend(theme: theme)

                Spacer(minLength: 6)

                if let exportMessage {
                    Text(exportMessage)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("\(selectedDate.rawValue) · \(statusText)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                FooterLink(label: "分享", systemImage: "square.on.square", action: onShare)
                FooterLink(label: "设置", action: onOpenSettings)
            }
        }
    }

    private var statusText: String {
        let base = HeatmapPalette.label(for: selectedKind)
        guard let selectedRecord else { return base }
        var flags: [String] = []
        if selectedRecord.inHengqin {
            flags.append(selectedRecord.manualHengqin ? "手动" : "GPS")
        }
        if selectedRecord.isLeave { flags.append("请假") }
        return flags.isEmpty ? base : "\(base) · \(flags.joined(separator: " / "))"
    }
}

private struct FooterLegend: View {
    let theme: AppTheme

    private let visibleKinds: [HeatmapKind] = [.gps, .manual, .leave, .bridge, .absent]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(visibleKinds, id: \.self) { kind in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(HeatmapPalette.color(for: kind, theme: theme))
                        .frame(width: 9, height: 9)
                    Text(HeatmapPalette.shortLabel(for: kind))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .help(HeatmapPalette.label(for: kind))
            }
        }
    }
}

private struct FooterLink: View {
    let label: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}
