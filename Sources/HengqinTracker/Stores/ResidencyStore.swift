import AppKit
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

    private static let themeKey = "hengqin.theme"
    private static let viewModeKey = "hengqin.viewMode"
    private static let visibleMonthKey = "hengqin.visibleMonth"
    private let recordsURL: URL

    private var calculator: ResidencyCalculator {
        ResidencyCalculator(calendar: calendar)
    }

    var stats: YearStats {
        calculator.yearStats(records: records)
    }

    init(records: [DateKey: DayRecord]? = nil, recordsURL: URL? = nil) {
        let today = DateKey(date: Date())
        self.today = today.year == 2026 ? today : DemoDataFactory.today
        self.recordsURL = recordsURL ?? Self.defaultRecordsURL()
        self.records = records ?? Self.loadRecords(from: self.recordsURL)
        self.selectedDate = self.today
        let rawViewMode = UserDefaults.standard.string(forKey: Self.viewModeKey) ?? HeatmapViewMode.year.rawValue
        self.viewMode = HeatmapViewMode(rawValue: rawViewMode) ?? .year
        let savedMonth = UserDefaults.standard.integer(forKey: Self.visibleMonthKey)
        self.visibleMonth = (1...12).contains(savedMonth) ? savedMonth : self.today.month
        let rawTheme = UserDefaults.standard.string(forKey: Self.themeKey) ?? AppTheme.sequoia.rawValue
        self.theme = AppTheme(rawValue: rawTheme) ?? .sequoia
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
        exportMessage = "已更新 \(date.rawValue)"
    }

    func showPreviousMonth() {
        visibleMonth = max(1, visibleMonth - 1)
    }

    func showNextMonth() {
        visibleMonth = min(12, visibleMonth + 1)
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
            let url = downloads.appendingPathComponent("横琴热力图-2026-\(today.rawValue).png")
            try data.write(to: url, options: .atomic)
            exportMessage = "已导出到下载目录"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func saveRecords() {
        do {
            try FileManager.default.createDirectory(
                at: recordsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let payload = Dictionary(uniqueKeysWithValues: records.map { ($0.key.rawValue, $0.value) })
            let data = try JSONEncoder().encode(payload)
            try data.write(to: recordsURL, options: .atomic)
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

    private static func defaultRecordsURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("HengqinTracker", isDirectory: true)
            .appendingPathComponent("records.json")
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
