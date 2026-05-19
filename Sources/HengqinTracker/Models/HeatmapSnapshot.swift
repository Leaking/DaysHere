import HengqinCore

struct HeatmapSnapshot {
    var records: [DateKey: DayRecord]
    var stats: YearStats
    var today: DateKey
    var theme: AppTheme
}
