import AppKit
import HengqinCore
import SwiftUI

/// Renders App Store-grade assets via SwiftUI `ImageRenderer`:
///   - icons/icon1024.png   — square 1024×1024 app icon (Mac App Store required)
///   - docs/app-store/screenshots/01-year-panel-light.png  (2560×1600)
///   - docs/app-store/screenshots/02-month-panel-light.png (2560×1600)
///   - docs/app-store/screenshots/03-year-panel-graphite.png (2560×1600)
///   - docs/app-store/screenshots/04-share-card.png (980×420 dashboard export)
///
/// Run via:
///     swift run HengqinTracker --generate-assets --out /path/to/repo
@MainActor
enum AssetGenerator {
    static func run(outputRoot: String) {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: outputRoot)
        let iconsDir = root.appendingPathComponent("icons")
        let shotsDir = root.appendingPathComponent("docs/app-store/screenshots")
        try? fm.createDirectory(at: iconsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: shotsDir, withIntermediateDirectories: true)

        let demoStore = makeDemoStore()
        let demoSnapshot = HeatmapSnapshot(
            records: demoStore.records,
            stats: demoStore.stats,
            today: demoStore.today,
            theme: .sequoia
        )

        // App icon
        save(view: AppIconView(),
             size: CGSize(width: 1024, height: 1024),
             to: iconsDir.appendingPathComponent("icon1024.png"))
        print("✓ icons/icon1024.png")

        // Screenshots — render the actual panel composited on a clean desktop.
        let cases: [(filename: String, theme: AppTheme, viewMode: HeatmapViewMode)] = [
            ("01-year-panel-light.png", .sequoia, .year),
            ("02-month-panel-light.png", .sonoma, .month),
            ("03-year-panel-graphite.png", .graphite, .year)
        ]
        for c in cases {
            demoStore.theme = c.theme
            demoStore.viewMode = c.viewMode
            let composite = ScreenshotComposite(store: demoStore, theme: c.theme)
            save(view: composite,
                 size: CGSize(width: 2560, height: 1600),
                 to: shotsDir.appendingPathComponent(c.filename))
            print("✓ docs/app-store/screenshots/\(c.filename)")
        }

        // Standalone share-card (the same view "复制图片" uses)
        let shareCard = HeatmapExportView(snapshot: demoSnapshot)
            .frame(width: 980, height: 420)
        save(view: shareCard,
             size: CGSize(width: 980, height: 420),
             to: shotsDir.appendingPathComponent("04-share-card.png"))
        print("✓ docs/app-store/screenshots/04-share-card.png")
    }

    // MARK: - Helpers

    private static func save<V: View>(view: V, size: CGSize, to url: URL) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 1
        guard let cg = renderer.cgImage else { return }
        let bitmap = NSBitmapImageRep(cgImage: cg)
        bitmap.size = size
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func makeDemoStore() -> ResidencyStore {
        // Use temp directories so we don't write into the user's real
        // ~/Library/Application Support folder.
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DaysHereAssetGen-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let profileStore = ProfileStore(
            profilesURL: tmp.appendingPathComponent("profiles.json"),
            recordsDirectory: tmp.appendingPathComponent("records", isDirectory: true),
            legacyRecordsURL: tmp.appendingPathComponent("records.json")
        )
        // Inject demo data into the active profile's records file BEFORE
        // ResidencyStore boots so the in-memory load picks it up.
        let recordsURL = profileStore.recordsURLForActiveProfile()
        let demoRecords = DemoDataFactory.makeRecords()
        if let data = try? JSONEncoder().encode(
            Dictionary(uniqueKeysWithValues: demoRecords.map { ($0.key.rawValue, $0.value) })
        ) {
            try? data.write(to: recordsURL, options: .atomic)
        }

        // iCloudSyncManager defaults to disabled; safe to use in CLI mode.
        return ResidencyStore(profileStore: profileStore)
    }
}

// MARK: - App Icon

/// 1024×1024 master icon. Same brand mark as the in-app PanelHeader logo:
/// a soft green-gradient rounded square with a centered "横" character.
struct AppIconView: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Apple HIG: macOS icons should NOT have transparent corners;
                // the system applies its own rounded mask at display time. So
                // we paint a full-bleed background.
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.85, blue: 0.55),
                            Color(red: 0.18, green: 0.56, blue: 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: size * 0.012)
                            .blendMode(.overlay)
                    )

                // Inner highlight from top
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    ))
                    .blendMode(.overlay)

                // Brand character
                Text("横")
                    .font(.system(size: size * 0.62, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: size * 0.012, x: 0, y: size * 0.008)
                    .offset(y: -size * 0.02)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Screenshot composite

/// Wraps the menu bar panel on a desktop backdrop. The panel is rendered at
/// its native 640×386 then scaled up so it dominates the 2560×1600 canvas,
/// the way real App Store marketing screenshots position a hero device.
struct ScreenshotComposite: View {
    @ObservedObject var store: ResidencyStore
    let theme: AppTheme

    var body: some View {
        ZStack {
            // Desktop backdrop
            theme.background
                .opacity(0.7)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.05), Color.clear, Color.black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                // Fake macOS menu bar (translucent strip)
                FakeMenuBar(daysCount: store.stats.naturalDays)

                Spacer()

                // Marketing caption above the panel
                VStack(spacing: 8) {
                    Text(captionTitle(theme: theme, viewMode: store.viewMode))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                    Text(captionSubtitle(theme: theme, viewMode: store.viewMode))
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer().frame(height: 36)

                // Hero panel — 2x scale up. forRendering=true disables
                // ScrollView wrap so ImageRenderer renders the heatmap.
                MenuBarPanelView(store: store, forRendering: true)
                    .frame(width: 640, height: 386)
                    .scaleEffect(2.4, anchor: .center)
                    .frame(width: 640 * 2.4, height: 386 * 2.4)
                    .shadow(color: .black.opacity(0.45), radius: 50, x: 0, y: 30)

                Spacer()
            }
        }
        .clipped()
    }

    private func captionTitle(theme: AppTheme, viewMode: HeatmapViewMode) -> String {
        switch viewMode {
        case .year:  return "一眼看见你的全年"
        case .month: return "想看哪个月，就翻到那一页"
        }
    }

    private func captionSubtitle(theme: AppTheme, viewMode: HeatmapViewMode) -> String {
        switch viewMode {
        case .year:  return "365 天，每个色块都是去过 / 没去过 / 还未到"
        case .month: return "日历卡片式，节假日 · 调休 · 请假一目了然"
        }
    }
}

private struct FakeMenuBar: View {
    let daysCount: Int

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("").font(.system(size: 16))    // hide apple logo for licensing safety
                Group {
                    Text("Finder")
                    Text("文件")
                    Text("编辑")
                    Text("视图")
                    Text("窗口")
                    Text("帮助")
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.leading, 16)

            Spacer()

            HStack(spacing: 18) {
                // Day counter — our app's status item
                Text("\(daysCount) 天")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                    )
                Text("87%")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                Text("周二 5月19日  14:32")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.trailing, 16)
        }
        .frame(height: 36)
        .background(Color.black.opacity(0.4))
        .background(.regularMaterial)
    }
}
