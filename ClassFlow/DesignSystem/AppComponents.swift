import SwiftUI

struct AppTag: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let symbol { Image(systemName: symbol) }
            Text(title)
        }
        .font(AppTypography.micro.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(tint.opacity(AppColors.tintOpacity), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct AppEmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: symbol)
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.accent)
                .padding(AppSpacing.lg)
                .background(AppColors.accent.opacity(AppColors.tintOpacity),
                            in: RoundedRectangle(cornerRadius: AppRadius.large))
                .accessibilityHidden(true)
            Text(title).font(AppTypography.sectionTitle)
            Text(message).font(AppTypography.secondary).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(AppButtonStyle(.primary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
    }
}

enum AppButtonRole: Equatable { case primary, secondary, tertiary, destructive, icon, floating }

struct AppButtonStyle: ButtonStyle {
    let role: AppButtonRole
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(_ role: AppButtonRole) { self.role = role }

    private var filled: Bool { role == .primary || role == .floating }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.secondary.weight(.semibold))
            .padding(.horizontal, role == .icon ? AppSpacing.sm : AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .frame(minWidth: AppSpacing.touchTarget, minHeight: AppSpacing.touchTarget)
            .foregroundStyle(filled ? AppColors.surface : (role == .destructive ? Color.red : AppColors.accent))
            .background(filled ? AppColors.accent : (role == .secondary ? AppColors.inset : Color.clear),
                        in: RoundedRectangle(cornerRadius: AppRadius.small))
            .contentShape(Rectangle())
            .opacity(!enabled ? 0.4 : (configuration.isPressed ? AppColors.pressedOpacity : 1))
            .animation(AppMotion.feedback(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct AppSheetStyle: ViewModifier {
    var expanded = false
    @Environment(\.dynamicTypeSize) private var dynamicType
    func body(content: Content) -> some View {
        content
            .presentationDetents(expanded || dynamicType.isAccessibilitySize ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(AppRadius.large)
            .tint(AppColors.accent)
    }
}

extension View {
    func appSheet(expanded: Bool = false) -> some View { modifier(AppSheetStyle(expanded: expanded)) }
    func appSurface(accent: Color? = nil) -> some View {
        self.padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(alignment: .leading) {
                if let accent {
                    Capsule().fill(accent).frame(width: AppSpacing.accentWidth)
                        .padding(.vertical, AppSpacing.lg)
                }
            }
    }
}
