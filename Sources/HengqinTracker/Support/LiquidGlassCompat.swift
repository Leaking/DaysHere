import SwiftUI

// macOS 26 ("Tahoe") introduces GlassEffectContainer / .glassEffect.
// Since we currently build against the macOS 15 SDK (Xcode 16), these APIs
// aren't visible at compile time. We expose the same call sites here and
// fall back to .regularMaterial, which gives a very similar Liquid Glass
// feel on macOS 15. When the project is later built with the macOS 26 SDK
// these wrappers can be re-pointed at the native GlassEffect APIs.

struct LiquidGlassContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
    }
}

extension View {
    func liquidPanel(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(.regularMaterial, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.22), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.18), radius: 32, x: 0, y: 18)
    }

    func liquidControl(cornerRadius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(.thinMaterial, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.16), lineWidth: 0.6))
    }
}
