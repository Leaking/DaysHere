import HengqinCore
import SwiftUI

enum HeatmapPalette {
    static func color(for kind: HeatmapKind, theme: AppTheme = .sequoia) -> Color {
        if theme == .tahoe {
            switch kind {
            case .gps: return Color(red: 0.91, green: 0.66, blue: 0.42)
            case .manual: return Color(red: 0.72, green: 0.35, blue: 0.17)
            case .leave: return Color(red: 0.48, green: 0.42, blue: 0.85)
            case .bridge: return Color(red: 0.95, green: 0.82, blue: 0.29)
            case .absent: return Color(nsColor: .quaternaryLabelColor).opacity(0.72)
            case .future: return Color(nsColor: .separatorColor).opacity(0.28)
            }
        }
        if theme == .sonoma {
            switch kind {
            case .gps: return Color(red: 0.44, green: 0.82, blue: 0.54)
            case .manual: return Color(red: 0.12, green: 0.48, blue: 0.30)
            case .leave: return Color(red: 0.31, green: 0.55, blue: 0.98)
            case .bridge: return Color(red: 0.94, green: 0.70, blue: 0.20)
            case .absent: return Color(nsColor: .quaternaryLabelColor).opacity(0.72)
            case .future: return Color(nsColor: .separatorColor).opacity(0.28)
            }
        }
        if theme == .graphite {
            switch kind {
            case .gps: return Color(red: 0.50, green: 0.74, blue: 0.56)
            case .manual: return Color(red: 0.26, green: 0.55, blue: 0.34)
            case .leave: return Color(red: 0.42, green: 0.55, blue: 0.92)
            case .bridge: return Color(red: 0.84, green: 0.66, blue: 0.30)
            case .absent: return Color(nsColor: .tertiaryLabelColor).opacity(0.70)
            case .future: return Color(nsColor: .separatorColor).opacity(0.24)
            }
        }

        switch kind {
        case .gps:
            return Color(red: 0.48, green: 0.75, blue: 0.48)
        case .manual:
            return Color(red: 0.18, green: 0.56, blue: 0.25)
        case .leave:
            return Color(red: 0.24, green: 0.48, blue: 0.94)
        case .bridge:
            return Color(red: 0.95, green: 0.74, blue: 0.24)
        case .absent:
            return Color(nsColor: .quaternaryLabelColor).opacity(0.72)
        case .future:
            return Color(nsColor: .separatorColor).opacity(0.28)
        }
    }

    static func label(for kind: HeatmapKind) -> String {
        switch kind {
        case .gps: "GPS 在横琴"
        case .manual: "手动标记"
        case .leave: "请假桥接"
        case .bridge: "假期桥接"
        case .absent: "未计入"
        case .future: "未来"
        }
    }
}
