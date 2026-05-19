import XCTest
@testable import HengqinCore

final class HeatmapModelTests: XCTestCase {
    func testHolidayCalendarUses2026WorkdayRules() {
        let calendar = HolidayCalendar2026()

        XCTAssertFalse(calendar.isWorkday(DateKey("2026-01-01")))
        XCTAssertTrue(calendar.isWorkday(DateKey("2026-01-04")))
        XCTAssertTrue(calendar.isWorkday(DateKey("2026-01-05")))
        XCTAssertFalse(calendar.isWorkday(DateKey("2026-02-15")))
    }

    func testResidencyCalculatorSeparatesHeatmapKinds() {
        let calendar = HolidayCalendar2026()
        let calculator = ResidencyCalculator(calendar: calendar)
        let records: [DateKey: DayRecord] = [
            DateKey("2026-01-05"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false),
            DateKey("2026-01-06"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: true),
            DateKey("2026-01-07"): DayRecord(inHengqin: false, isLeave: true, manualHengqin: false),
            DateKey("2026-01-09"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false),
            DateKey("2026-01-12"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false)
        ]
        let bridged = Set([DateKey("2026-01-07"), DateKey("2026-01-10"), DateKey("2026-01-11")])

        XCTAssertEqual(calculator.heatmapKind(for: DateKey("2026-01-05"), records: records, bridgedDays: bridged, today: DateKey("2026-01-12")), .gps)
        XCTAssertEqual(calculator.heatmapKind(for: DateKey("2026-01-06"), records: records, bridgedDays: bridged, today: DateKey("2026-01-12")), .manual)
        XCTAssertEqual(calculator.heatmapKind(for: DateKey("2026-01-07"), records: records, bridgedDays: bridged, today: DateKey("2026-01-12")), .leave)
        XCTAssertEqual(calculator.heatmapKind(for: DateKey("2026-01-10"), records: records, bridgedDays: bridged, today: DateKey("2026-01-12")), .bridge)
        XCTAssertEqual(calculator.heatmapKind(for: DateKey("2026-01-08"), records: records, bridgedDays: bridged, today: DateKey("2026-01-12")), .absent)
        XCTAssertEqual(calculator.heatmapKind(for: DateKey("2026-01-13"), records: records, bridgedDays: bridged, today: DateKey("2026-01-12")), .future)
    }

    func testYearHeatmapLayoutCreatesMondayStartColumnsAndMonthLabels() {
        let layout = YearHeatmapLayout(year: 2026, weekStart: .monday)

        XCTAssertEqual(layout.columns.count, 53)
        XCTAssertEqual(layout.columns[0].map { $0?.rawValue }, [nil, nil, nil, "2026-01-01", "2026-01-02", "2026-01-03", "2026-01-04"])
        XCTAssertNil(layout.columns.last?.last ?? nil)
        XCTAssertEqual(layout.weekdayLabels, ["一", "", "三", "", "五", "", "日"])
        XCTAssertEqual(layout.monthLabels.first?.month, 1)
        XCTAssertEqual(layout.monthLabels.last?.month, 12)
    }

    func testMonthHeatmapLayoutCreatesMondayStartCalendarGrid() {
        let layout = MonthHeatmapLayout(year: 2026, month: 5, weekStart: .monday)

        XCTAssertEqual(layout.weekdayLabels, ["一", "二", "三", "四", "五", "六", "日"])
        XCTAssertEqual(layout.weeks.count, 5)
        XCTAssertEqual(layout.weeks[0].map { $0?.rawValue }, [nil, nil, nil, nil, "2026-05-01", "2026-05-02", "2026-05-03"])
        XCTAssertEqual(layout.weeks[4].map { $0?.rawValue }, ["2026-05-25", "2026-05-26", "2026-05-27", "2026-05-28", "2026-05-29", "2026-05-30", "2026-05-31"])
    }

    func testYearStatsCountsNaturalAndWorkdays() {
        let calculator = ResidencyCalculator(calendar: HolidayCalendar2026())
        let records: [DateKey: DayRecord] = [
            DateKey("2026-01-05"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false),
            DateKey("2026-01-06"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false),
            DateKey("2026-01-09"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false),
            DateKey("2026-01-12"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false)
        ]

        let stats = calculator.yearStats(records: records)

        XCTAssertEqual(stats.naturalDays, 6)
        XCTAssertEqual(stats.workdays, 4)
        XCTAssertTrue(stats.bridgedDays.contains(DateKey("2026-01-10")))
        XCTAssertTrue(stats.bridgedDays.contains(DateKey("2026-01-11")))
    }

    func testEmptyRecordsStartAtZeroDays() {
        let calculator = ResidencyCalculator(calendar: HolidayCalendar2026())

        let stats = calculator.yearStats(records: [:])

        XCTAssertEqual(stats.naturalDays, 0)
        XCTAssertEqual(stats.workdays, 0)
        XCTAssertTrue(stats.bridgedDays.isEmpty)
    }

    func testWeekendGpsDoesNotCountButManualWeekendDoes() {
        let calculator = ResidencyCalculator(calendar: HolidayCalendar2026())
        let gpsOnlyWeekend: [DateKey: DayRecord] = [
            DateKey("2026-01-10"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: false)
        ]
        let manualWeekend: [DateKey: DayRecord] = [
            DateKey("2026-01-10"): DayRecord(inHengqin: true, isLeave: false, manualHengqin: true)
        ]

        XCTAssertEqual(calculator.yearStats(records: gpsOnlyWeekend).naturalDays, 0)
        XCTAssertEqual(calculator.yearStats(records: manualWeekend).naturalDays, 1)
    }

    func testRecordMutationsMatchChromeManualMarkingModel() {
        var records: [DateKey: DayRecord] = [:]
        let date = DateKey("2026-03-02")

        DayRecordMutator.apply(.markInHengqin, to: date, records: &records)
        XCTAssertEqual(records[date], DayRecord(inHengqin: true, isLeave: false, manualHengqin: true))

        DayRecordMutator.apply(.markLeave, to: date, records: &records)
        XCTAssertEqual(records[date], DayRecord(inHengqin: true, isLeave: true, manualHengqin: true))

        DayRecordMutator.apply(.clear, to: date, records: &records)
        XCTAssertNil(records[date])
    }
}
