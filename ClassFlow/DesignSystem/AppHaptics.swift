import UIKit

@MainActor
enum AppHaptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .light)

    static func selected() { selection.selectionChanged() }
    static func success() { notification.notificationOccurred(.success) }
    static func warning() { notification.notificationOccurred(.warning) }
    static func returnToToday() { impact.impactOccurred() }
}
