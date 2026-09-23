import SwiftUI

enum AppMotion {
    static func feedback(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.18) : .smooth(duration: 0.22)
    }
    static func content(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.18) : .snappy(duration: 0.28, extraBounce: 0)
    }
    static let pressedScale: CGFloat = 0.985
}

struct AppPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? AppColors.pressedOpacity : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? AppMotion.pressedScale : 1)
            .animation(AppMotion.feedback(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
