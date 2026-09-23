import SwiftUI
import UIKit
import ClassFlowCore

enum AppColors {
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let inset = Color(uiColor: .tertiarySystemGroupedBackground)
    static let accent = CourseAccent.iris.color
    static let separator = Color(uiColor: .separator).opacity(0.3)
    static let warning = CourseAccent.ochre.color
    static let tintOpacity = 0.12
    static let pressedOpacity = 0.76
    static let subtleOpacity = 0.06
}

/// Deliberate palette exceptions to semantic system colors, kept entirely in this file.
/// Existing persisted keys retain their meaning; Phase 4 exposes all ten swatches.
enum CourseAccent: String, CaseIterable {
    case slate, teal, sage, ochre, rose, iris, plum, clay, olive, denim

    var color: Color {
        let pair: (UInt32, UInt32)
        switch self {
        case .slate: pair = (0x526B8A, 0xA3BAD4)
        case .teal: pair = (0x267171, 0x8CC9C6)
        case .sage: pair = (0x4B7458, 0xA0C5AA)
        case .ochre: pair = (0x896522, 0xD7B878)
        case .rose: pair = (0x925268, 0xDFA8B7)
        case .iris: pair = (0x696394, 0xBDB5E1)
        case .plum: pair = (0x805A82, 0xCAA6CE)
        case .clay: pair = (0x8E5844, 0xD8AD96)
        case .olive: pair = (0x636B37, 0xBDC78C)
        case .denim: pair = (0x496F91, 0x9ABEDF)
        }
        return Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? pair.1 : pair.0
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

extension CourseColor {
    var swiftUIColor: Color {
        switch self {
        case .blue: CourseAccent.slate.color
        case .teal: CourseAccent.teal.color
        case .green: CourseAccent.sage.color
        case .orange: CourseAccent.ochre.color
        case .pink: CourseAccent.rose.color
        case .purple: CourseAccent.iris.color
        case .plum: CourseAccent.plum.color
        case .clay: CourseAccent.clay.color
        case .olive: CourseAccent.olive.color
        case .denim: CourseAccent.denim.color
        }
    }

    var displayName: String {
        switch self {
        case .blue: "雾蓝"
        case .teal: "青瓷"
        case .green: "鼠尾草"
        case .orange: "秋麦"
        case .pink: "干玫瑰"
        case .purple: "鸢尾"
        case .plum: "灰梅"
        case .clay: "陶土"
        case .olive: "橄榄"
        case .denim: "丹宁"
        }
    }
}
