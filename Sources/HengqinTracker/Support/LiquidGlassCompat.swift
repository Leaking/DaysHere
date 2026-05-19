import SwiftUI

struct LiquidGlassContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func liquidPanel(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self
                .background(.regularMaterial, in: shape)
                .glassEffect(.regular.interactive(), in: shape)
                .overlay(shape.stroke(.white.opacity(0.28), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.22), radius: 34, x: 0, y: 18)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.22), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.18), radius: 32, x: 0, y: 18)
        }
    }

    @ViewBuilder
    func liquidControl(cornerRadius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            self
                .background(.thinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.16), lineWidth: 0.6))
        }
    }
}
