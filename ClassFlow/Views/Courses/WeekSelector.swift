import SwiftUI
import ClassFlowCore

@MainActor
struct WeekSelector: View {
    @Binding var selection: Set<Int>
    let totalWeeks: Int
    @State private var first = 1
    @State private var last = 1
    @ScaledMetric(relativeTo: .body) private var cellWidth = AppSpacing.touchTarget
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var weeks: [Int] { Array(1...max(1, totalWeeks)) }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(ActiveWeeksFormatter.string(Array(selection), totalWeeks: totalWeeks))
                .font(AppTypography.secondary).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { shortcuts }
                VStack(alignment: .leading) { shortcuts }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth))], spacing: AppSpacing.sm) {
                ForEach(weeks, id: \.self) { week in
                    Button {
                        withAnimation(AppMotion.feedback(reduceMotion: reduceMotion)) {
                            if selection.contains(week) { selection.remove(week) } else { selection.insert(week) }
                        }
                        AppHaptics.selected()
                    } label: {
                        Text("\(week)").font(AppTypography.body)
                            .frame(maxWidth: .infinity, minHeight: cellWidth)
                            .foregroundStyle(selection.contains(week) ? AppColors.surface : AppColors.accent)
                            .background(selection.contains(week) ? AppColors.accent : AppColors.inset,
                                in: RoundedRectangle(cornerRadius: AppRadius.small))
                    }
                    .buttonStyle(AppPressStyle())
                    .accessibilityLabel("第\(week)周")
                    .accessibilityValue(selection.contains(week) ? "已选择" : "未选择")
                }
            }
            DisclosureGroup("选择连续区间") {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    LabeledContent("起始周") {
                        Picker("起始周", selection: $first) { ForEach(weeks, id: \.self) { Text("第\($0)周").tag($0) } }
                            .pickerStyle(.menu).labelsHidden().accessibilityLabel("起始周").frame(minHeight: AppSpacing.touchTarget)
                    }
                    LabeledContent("结束周") {
                        Picker("结束周", selection: $last) { ForEach(weeks.filter { $0 >= first }, id: \.self) { Text("第\($0)周").tag($0) } }
                            .pickerStyle(.menu).labelsHidden().accessibilityLabel("结束周").frame(minHeight: AppSpacing.touchTarget)
                    }
                    Button("应用区间") { choose(Set(first...max(first, last))) }.buttonStyle(AppButtonStyle(.secondary))
                }.padding(.top, AppSpacing.sm)
            }.font(AppTypography.secondary)
        }
        .onAppear { last = totalWeeks }
        .onChange(of: first) { _, value in last = max(last, value) }
    }
    private var shortcuts: some View {
        Group {
            Button("全部") { choose((try? ActiveWeeks.every(1...max(1, totalWeeks)).values) ?? []) }
            Button("单周") { choose((try? ActiveWeeks.odd(1...max(1, totalWeeks)).values) ?? []) }
            Button("双周") { choose((try? ActiveWeeks.even(1...max(1, totalWeeks)).values) ?? []) }
            Button("清除") { choose([]) }
        }.buttonStyle(AppButtonStyle(.secondary))
    }
    private func choose(_ values: Set<Int>) { selection = values; AppHaptics.selected() }
}
