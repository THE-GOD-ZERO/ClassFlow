import SwiftUI
import ClassFlowCore

struct ReplacementWeekdaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    let onSelect: (Weekday) -> Bool

    init(title: String = "选择当天课表",
         message: String = "检测到调休，但尚未确定执行哪一天的课表。",
         onSelect: @escaping (Weekday) -> Bool) {
        self.title = title
        self.message = message
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(message).foregroundStyle(.secondary)
                }
                Section("执行课表") {
                    ForEach(Weekday.allCases, id: \.rawValue) { weekday in
                        Button {
                            if onSelect(weekday) { dismiss() }
                        } label: {
                            HStack {
                                Text(weekday.chineseName)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(AppTypography.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: AppSpacing.touchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("按\(weekday.chineseName)课表上课")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
