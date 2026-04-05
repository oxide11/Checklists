import SwiftUI

// MARK: - Night Vision ViewModifier

/// Applies red-on-black rendering for night-adapted vision.
/// Must be applied at the app root AND inside every .sheet / .fullScreenCover
/// since those create separate UIHostingController hierarchies.
struct NightVisionModifier: ViewModifier {
    @AppStorage("nightVisionEnabled") private var nightVisionEnabled = false

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(nightVisionEnabled ? .dark : nil)
            .colorMultiply(nightVisionEnabled ? .red : .white)
    }
}

extension View {
    func nightVisionAware() -> some View {
        modifier(NightVisionModifier())
    }
}
