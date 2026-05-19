enum HeatmapViewMode: String, CaseIterable, Identifiable {
    case year
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .year: "全年"
        case .month: "本月"
        }
    }
}
