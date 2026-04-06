import SwiftUI

// MARK: - Night Vision Environment Key

private struct NightVisionEnabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var nightVisionEnabled: Bool {
        get { self[NightVisionEnabledKey.self] }
        set { self[NightVisionEnabledKey.self] = newValue }
    }
}

// MARK: - Night Vision ViewModifier

/// Applies red-on-black rendering for night-adapted vision.
/// Uses semantic foreground/tint styling instead of .colorMultiply(.red)
/// for much better contrast and readability.
/// Must be applied at the app root AND inside every .sheet / .fullScreenCover
/// since those create separate UIHostingController hierarchies.
struct NightVisionModifier: ViewModifier {
    @AppStorage("nightVisionEnabled") private var nightVisionEnabled = false

    private let nightVisionRed = Color(red: 0.85, green: 0.1, blue: 0.1)

    func body(content: Content) -> some View {
        if nightVisionEnabled {
            content
                .preferredColorScheme(.dark)
                .tint(nightVisionRed)
                .foregroundStyle(nightVisionRed)
                .environment(\.nightVisionEnabled, true)
                .background(Color.black.ignoresSafeArea())
        } else {
            content
                .environment(\.nightVisionEnabled, false)
        }
    }
}

// MARK: - View Extensions

extension View {
    func nightVisionAware() -> some View {
        modifier(NightVisionModifier())
    }
}
