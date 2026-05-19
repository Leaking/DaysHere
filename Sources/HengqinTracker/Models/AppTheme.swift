import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case sequoia
    case tahoe
    case sonoma
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sequoia: "深空"
        case .tahoe: "日落"
        case .sonoma: "青绿"
        case .graphite: "石墨"
        }
    }

    var accent: Color {
        switch self {
        case .sequoia: Color(red: 0.30, green: 0.49, blue: 0.88)
        case .tahoe: Color(red: 0.93, green: 0.32, blue: 0.50)
        case .sonoma: Color(red: 0.16, green: 0.70, blue: 0.61)
        case .graphite: Color(red: 0.55, green: 0.56, blue: 0.62)
        }
    }

    var background: LinearGradient {
        switch self {
        case .sequoia:
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.22, blue: 0.42),
                    Color(red: 0.28, green: 0.20, blue: 0.46),
                    Color(red: 0.16, green: 0.32, blue: 0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .tahoe:
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.50, blue: 0.35),
                    Color(red: 0.76, green: 0.23, blue: 0.43),
                    Color(red: 0.34, green: 0.20, blue: 0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sonoma:
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.35, blue: 0.34),
                    Color(red: 0.12, green: 0.52, blue: 0.48),
                    Color(red: 0.07, green: 0.20, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .graphite:
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.15),
                    Color(red: 0.22, green: 0.22, blue: 0.27),
                    Color(red: 0.09, green: 0.09, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
