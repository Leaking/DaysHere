import HengqinCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var store: ResidencyStore
    var openSettings: () -> Void = {}
    /// Disables scroll views and onAppear animations — required when this
    /// view is rendered through `ImageRenderer` (asset generation, share).
    var forRendering: Bool = false

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
                .frame(maxWidth: .infinity, alignment: .top)
                // No fixed maxHeight — VStack's intrinsic height drives the
                // popover. AppDelegate observes store.viewMode and animates
                // popover.contentSize so the window itself resizes smoothly.
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: store.viewMode)
    }

    /// Heatmap height per view mode. AppDelegate must use
    /// `popoverSize(for:)` to keep the popover frame in sync.
    static let yearHeatmapHeight: CGFloat = 100
    static let monthHeatmapHeight: CGFloat = 150

    /// Sum of every fixed-height row above + below the heatmap (header,
    /// stats, toggle divider, footer, vertical padding). Used by
    /// `popoverSize(for:)` to compute the total popover height.
    private static let chromeHeight: CGFloat = 222

    /// Total popover height for a given view mode. AppDelegate calls this
    /// and animates `popover.contentSize` whenever `store.viewMode` flips.
    static func popoverSize(for viewMode: HeatmapViewMode, width: CGFloat = 640) -> NSSize {
        let bodyHeight = viewMode == .year ? yearHeatmapHeight : monthHeatmapHeight
        return NSSize(width: width, height: chromeHeight + bodyHeight)
    }

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
                onAction: { date, action in store.apply(action, to: date) },
                scrollable: !forRendering
            )
            .frame(height: Self.yearHeatmapHeight, alignment: .topLeading)
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
            .frame(height: Self.monthHeatmapHeight, alignment: .topLeading)
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
        // Use onTapGesture instead of Button — macOS Buttons (even .plain)
        // can show a system focus ring on the last-clicked control, which
        // visually conflicts with our own "active" indicator and made the
        // previously-clicked swatch look selected even after switching themes.
        ZStack {
            Circle()
                .fill(item.background)
                .frame(width: active ? 14 : 12, height: active ? 14 : 12)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                )
            if active {
                // Echo the theme's own accent color in the selection ring
                // so the border feels tied to the swatch's inner gradient
                // (instead of a flat primary stroke that fights the color).
                Circle()
                    .stroke(item.accent.opacity(0.95), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                    .shadow(color: item.accent.opacity(0.45), radius: 3)
            }
        }
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
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
                Spacer()
            }
        }
    }
}

private struct SegmentedToggle: View {
    @Binding var viewMode: HeatmapViewMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach([HeatmapViewMode.year, HeatmapViewMode.month], id: \.self) { mode in
                segment(mode)
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.07))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        )
    }

    private func segment(_ mode: HeatmapViewMode) -> some View {
        let active = viewMode == mode
        let label = mode == .year ? "全年" : "本月"

        // No matchedGeometryEffect: a horizontal slide on the indicator was
        // fighting the popover's vertical resize, which looked jittery. Each
        // segment now keeps its own anchored capsule background and just
        // cross-fades opacity in place — vertical resize is the only motion.
        return Text(label)
            .font(.system(size: 11.5, weight: active ? .semibold : .medium))
            .tracking(-0.02)
            .foregroundStyle(active ? Color.primary : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.12), radius: 2.5, x: 0, y: 1)
                    .opacity(active ? 1 : 0)
            )
            .contentShape(Capsule())
            // onTapGesture (not Button) keeps the macOS keyboard focus ring
            // off the segment, which had bled through .buttonStyle(.plain).
            .onTapGesture {
                guard viewMode != mode else { return }
                viewMode = mode
            }
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
                    Text("\(selectedDate.rawValue) \(DayTooltipFormatter.weekdayName(selectedDate)) · \(statusText)")
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
