import AppKit
import Combine
import HengqinCore
import SwiftUI

@MainActor
final class ResidencyStore: ObservableObject {
    let calendar = HolidayCalendar2026()
    let today: DateKey

    @Published private(set) var records: [DateKey: DayRecord]
    @Published var selectedDate: DateKey?
    @Published var viewMode: HeatmapViewMode {
        didSet {
            UserDefaults.standard.set(viewMode.rawValue, forKey: Self.viewModeKey)
        }
    }
    @Published var visibleMonth: Int {
        didSet {
            UserDefaults.standard.set(visibleMonth, forKey: Self.visibleMonthKey)
        }
    }
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey)
        }
    }
    @Published var exportMessage: String?
    @Published private(set) var lastImportSummary: String?

    let sync: iCloudSyncManager
    let profileStore: ProfileStore

    private static let themeKey = "hengqin.theme"
    private static let viewModeKey = "hengqin.viewMode"
    private static let visibleMonthKey = "hengqin.visibleMonth"

    /// The records file URL for the currently active profile.
    private var recordsURL: URL {
        profileStore.recordsURLForActiveProfile()
    }

    private var profileObserver: AnyCancellable?

    private var calculator: ResidencyCalculator {
        ResidencyCalculator(calendar: calendar)
    }

    var stats: YearStats {
        calculator.yearStats(records: records)
    }

    var activeProfile: LocationProfile { profileStore.activeProfile }

    init(
        profileStore: ProfileStore = ProfileStore(),
        sync: iCloudSyncManager? = nil
    ) {
        let today = DateKey(date: Date())
        self.today = today.year == 2026 ? today : DemoDataFactory.today
        self.profileStore = profileStore

        let suffix = profileStore.kvsKeySuffix(for: profileStore.activeProfile)
        self.sync = sync ?? iCloudSyncManager(keySuffix: suffix)

        let initialURL = profileStore.recordsURLForActiveProfile()
        self.records = Self.loadRecords(from: initialURL)
        self.selectedDate = self.today

        let rawViewMode = UserDefaults.standard.string(forKey: Self.viewModeKey) ?? HeatmapViewMode.year.rawValue
        self.viewMode = HeatmapViewMode(rawValue: rawViewMode) ?? .year

        let savedMonth = UserDefaults.standard.integer(forKey: Self.visibleMonthKey)
        self.visibleMonth = (1...12).contains(savedMonth) ? savedMonth : self.today.month

        let rawTheme = UserDefaults.standard.string(forKey: Self.themeKey) ?? AppTheme.sequoia.rawValue
        self.theme = AppTheme(rawValue: rawTheme) ?? .sequoia

        self.sync.onExternalChange = { [weak self] change in
            guard let self else { return }
            if case .adopt(let remote) = change {
                self.adoptRemoteRecords(remote)
            }
        }
        self.sync.bootstrap(currentRecords: self.records)

        profileObserver = profileStore.$collection
            .removeDuplicates(by: { $0.activeProfileId == $1.activeProfileId })
            .dropFirst()
            .sink { [weak self] collection in
                guard let self else { return }
                self.handleProfileSwitch(to: collection.activeProfile)
            }
    }

    func heatmapKind(for date: DateKey) -> HeatmapKind {
        calculator.heatmapKind(for: date, records: records, bridgedDays: stats.bridgedDays, today: today)
    }

    func record(for date: DateKey) -> DayRecord? {
        records[date]
    }

    func select(_ date: DateKey) {
        selectedDate = date
        visibleMonth = date.month
        exportMessage = nil
    }

    func apply(_ action: DayRecordAction, to date: DateKey) {
        DayRecordMutator.apply(action, to: date, records: &records)
        selectedDate = date
        visibleMonth = date.month
        saveRecords()
        sync.push(records: records)
        exportMessage = "已更新 \(date.rawValue)"
    }

    func showPreviousMonth() {
        visibleMonth = max(1, visibleMonth - 1)
    }

    func showNextMonth() {
        visibleMonth = min(12, visibleMonth + 1)
    }

    // MARK: - Import / Export

    /// Export records for a specific profile. Defaults to the active profile.
    /// Non-active profiles are read from disk directly.
    func exportBackupData(for profileId: UUID? = nil) throws -> Data {
        let target = profileId ?? activeProfile.id
        if target == activeProfile.id {
            return try DataBackup.encode(records: records)
        }
        guard let profile = profileStore.collection.profile(with: target) else {
            throw ImportExportError.profileNotFound
        }
        let url = profileStore.recordsURL(for: profile)
        let snapshot = Self.loadRecords(from: url)
        return try DataBackup.encode(records: snapshot)
    }

    /// Replace all records of the specified profile. For the **active** profile
    /// the in-memory state is updated and iCloud is pushed immediately;
    /// otherwise the JSON file is written directly and iCloud will pick the
    /// change up next time the user switches into that profile.
    func importBackupReplacingAll(from data: Data, into profileId: UUID? = nil) throws -> ImportSummary {
        let backup = try DataBackup.decode(data)
        let target = profileId ?? activeProfile.id

        if target == activeProfile.id {
            let before = records.count
            records = backup.records
            saveRecords()
            sync.push(records: records, force: true)
            let summary = ImportSummary(
                replacedCount: before,
                importedCount: backup.records.count,
                exportDate: backup.exportDate,
                profileName: activeProfile.name
            )
            lastImportSummary = summary.shortDescription
            return summary
        }

        guard let profile = profileStore.collection.profile(with: target) else {
            throw ImportExportError.profileNotFound
        }
        let url = profileStore.recordsURL(for: profile)
        let before = Self.loadRecords(from: url).count
        let payload = Dictionary(uniqueKeysWithValues: backup.records.map { ($0.key.rawValue, $0.value) })
        let encoded = try JSONEncoder().encode(payload)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoded.write(to: url, options: .atomic)

        let summary = ImportSummary(
            replacedCount: before,
            importedCount: backup.records.count,
            exportDate: backup.exportDate,
            profileName: profile.name
        )
        lastImportSummary = summary.shortDescription
        return summary
    }

    enum ImportExportError: LocalizedError {
        case profileNotFound
        var errorDescription: String? {
            switch self {
            case .profileNotFound: return "未找到目标坐标档案"
            }
        }
    }

    struct ImportSummary {
        let replacedCount: Int
        let importedCount: Int
        let exportDate: String
        let profileName: String

        var shortDescription: String {
            "「\(profileName)」已导入 \(importedCount) 天 · 替换原有 \(replacedCount) 天"
        }
    }

    // MARK: - Heatmap export image

    /// Render a shareable dashboard image and copy it to the system pasteboard.
    /// The shape matches the file-export view so the look is consistent.
    func copyDashboardImage() {
        guard let image = renderShareableImage() else {
            exportMessage = "复制失败：无法生成图片"
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        exportMessage = "已复制图片到剪贴板"
    }

    private func renderShareableImage() -> NSImage? {
        let snapshot = HeatmapSnapshot(
            records: records,
            stats: stats,
            today: today,
            theme: theme
        )
        let exportView = HeatmapExportView(snapshot: snapshot)
            .frame(width: 980, height: 420)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: exportView)
        renderer.proposedSize = ProposedViewSize(width: 980, height: 420)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }

    func exportHeatmapImage() {
        let snapshot = HeatmapSnapshot(
            records: records,
            stats: stats,
            today: today,
            theme: theme
        )
        let exportView = HeatmapExportView(snapshot: snapshot)
            .frame(width: 980, height: 420)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: exportView)
        renderer.proposedSize = ProposedViewSize(width: 980, height: 420)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage, let data = image.pngData else {
            exportMessage = "导出失败：无法生成图片"
            return
        }

        do {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let stem = "横琴热力图-2026-\(activeProfile.name)-\(today.rawValue).png"
            let url = downloads.appendingPathComponent(stem)
            try data.write(to: url, options: .atomic)
            exportMessage = "已导出到下载目录"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Internal

    private func handleProfileSwitch(to profile: LocationProfile) {
        let nextURL = profileStore.recordsURL(for: profile)
        records = Self.loadRecords(from: nextURL)
        selectedDate = today
        exportMessage = "已切换到「\(profile.name)」"

        sync.switchProfile(suffix: profileStore.kvsKeySuffix(for: profile))
        sync.bootstrap(currentRecords: records)
    }

    private func adoptRemoteRecords(_ remote: [DateKey: DayRecord]) {
        guard remote != records else { return }
        records = remote
        saveRecords()
        exportMessage = "已通过 iCloud 同步"
    }

    private func saveRecords() {
        let url = recordsURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let payload = Dictionary(uniqueKeysWithValues: records.map { ($0.key.rawValue, $0.value) })
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: .atomic)
        } catch {
            exportMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private static func loadRecords(from url: URL) -> [DateKey: DayRecord] {
        guard
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode([String: DayRecord].self, from: data)
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: payload.map { (DateKey($0.key), $0.value) })
    }
}

private extension NSImage {
    var pngData: Data? {
        guard
            let tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
