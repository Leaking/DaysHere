public enum DayRecordAction: Sendable {
    case markInHengqin
    case unmarkInHengqin
    case markLeave
    case unmarkLeave
    case clear
}

public enum DayRecordMutator {
    public static func apply(
        _ action: DayRecordAction,
        to date: DateKey,
        records: inout [DateKey: DayRecord]
    ) {
        switch action {
        case .markInHengqin:
            var record = records[date] ?? DayRecord(inHengqin: false, isLeave: false, manualHengqin: false)
            record.inHengqin = true
            record.manualHengqin = true
            records[date] = record

        case .unmarkInHengqin:
            guard var record = records[date] else { return }
            record.inHengqin = false
            record.manualHengqin = false
            writeOrRemove(record, for: date, records: &records)

        case .markLeave:
            var record = records[date] ?? DayRecord(inHengqin: false, isLeave: false, manualHengqin: false)
            record.isLeave = true
            records[date] = record

        case .unmarkLeave:
            guard var record = records[date] else { return }
            record.isLeave = false
            writeOrRemove(record, for: date, records: &records)

        case .clear:
            records.removeValue(forKey: date)
        }
    }

    private static func writeOrRemove(
        _ record: DayRecord,
        for date: DateKey,
        records: inout [DateKey: DayRecord]
    ) {
        if record.inHengqin || record.isLeave || record.manualHengqin {
            records[date] = record
        } else {
            records.removeValue(forKey: date)
        }
    }
}
