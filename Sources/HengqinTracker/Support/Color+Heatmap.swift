import HengqinCore
import SwiftUI

enum HeatmapPalette {
    static func color(for kind: HeatmapKind, theme: AppTheme = .sequoia) -> Color {
        let p = palette(for: theme)
        switch kind {
        case .gps:     return p.gps
        case .manual:  return p.manual
        case .leave:   return p.leave
        case .bridge:  return p.holiday
        case .absent:  return p.none
        case .future:  return p.future
        }
    }

    static func textColor(for kind: HeatmapKind) -> Color {
        switch kind {
        case .manual, .leave: return Color.white.opacity(0.98)
        case .gps, .bridge:   return Color.black.opacity(0.78)
        default:              return Color.primary.opacity(0.78)
        }
    }

    static func subtleForeground(for kind: HeatmapKind) -> Color {
        switch kind {
        case .manual, .leave: return Color.white.opacity(0.85)
        case .gps, .bridge:   return Color.black.opacity(0.50)
        default:              return Color.secondary
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

    static func shortLabel(for kind: HeatmapKind) -> String {
        switch kind {
        case .gps: "GPS"
        case .manual: "手动"
        case .leave: "请假"
        case .bridge: "桥接"
        case .absent: "未计"
        case .future: "未来"
        }
    }

    private struct Palette {
        let gps: Color
        let manual: Color
        let leave: Color
        let holiday: Color
        let none: Color
        let future: Color
    }

    // Light-mode neutral grays (design); dark mode uses NSColor.tertiary/separator
    private static let neutralNone   = Color(red: 0.819, green: 0.827, blue: 0.831) // #D1D3D4
    private static let neutralFuture = Color(red: 0.917, green: 0.929, blue: 0.929) // #EAEDED

    private static func palette(for theme: AppTheme) -> Palette {
        switch theme {
        case .sequoia:
            // default · 浅绿 / 深绿 / 蓝 / 黄
            return Palette(
                gps:     Color(red: 0.478, green: 0.753, blue: 0.478), // #7AC07A
                manual:  Color(red: 0.184, green: 0.561, blue: 0.247), // #2F8F3F
                leave:   Color(red: 0.239, green: 0.482, blue: 0.941), // #3D7BF0
                holiday: Color(red: 0.949, green: 0.737, blue: 0.239), // #F2BC3D
                none:    neutralNone,
                future:  neutralFuture
            )
        case .tahoe:
            // warm · 橙 / 深棕红 / 紫 / 亮黄
            return Palette(
                gps:     Color(red: 0.910, green: 0.659, blue: 0.420), // #E8A86B
                manual:  Color(red: 0.722, green: 0.353, blue: 0.169), // #B85A2B
                leave:   Color(red: 0.482, green: 0.424, blue: 0.847), // #7B6CD8
                holiday: Color(red: 0.949, green: 0.824, blue: 0.290), // #F2D24A
                none:    neutralNone,
                future:  neutralFuture
            )
        case .sonoma:
            // ocean · 青 / 深青 / 紫蓝 / 橙黄
            return Palette(
                gps:     Color(red: 0.373, green: 0.749, blue: 0.788), // #5FBFC9
                manual:  Color(red: 0.102, green: 0.431, blue: 0.478), // #1A6E7A
                leave:   Color(red: 0.486, green: 0.424, blue: 0.969), // #7C6CF7
                holiday: Color(red: 0.937, green: 0.690, blue: 0.298), // #EFB04C
                none:    neutralNone,
                future:  neutralFuture
            )
        case .graphite:
            // emerald · 翠绿 / 深绿 / 蓝 / 黄
            return Palette(
                gps:     Color(red: 0.435, green: 0.816, blue: 0.541), // #6FD08A
                manual:  Color(red: 0.122, green: 0.478, blue: 0.298), // #1F7A4C
                leave:   Color(red: 0.310, green: 0.545, blue: 0.984), // #4F8BFB
                holiday: Color(red: 0.941, green: 0.706, blue: 0.196), // #F0B432
                none:    neutralNone,
                future:  neutralFuture
            )
        }
    }
}
