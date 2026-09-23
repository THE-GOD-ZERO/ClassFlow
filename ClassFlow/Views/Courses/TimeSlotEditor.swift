import SwiftUI
import ClassFlowCore

struct TimeSlotDraft: Identifiable, Equatable {
    var id: Int { section }
    let section: Int
    var start: Int
    var end: Int
    init(section: Int, start: Int, end: Int) {
        self.section = section; self.start = start; self.end = end
    }
    func definition() throws -> TimeSlotDefinition {
        try TimeSlotDefinition(sectionNumber: section, startMinute: start, endMinute: end)
    }
}

@MainActor
struct TimeSlotEditor: View {
    let initial: [TimeSlotDraft]
    let save: ([TimeSlotDefinition]) throws -> Void
    @State private var rows: [TimeSlotDraft]
    @State private var exit = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    private var issues: [String] {
        var result = rows.filter { $0.start >= $0.end }.map { "第\($0.section)节的结束时间须晚于开始时间。" }
        for (first, second) in zip(rows, rows.dropFirst()) where first.end > second.start {
            result.append("第\(first.section)节与第\(second.section)节时间重叠，请调整。")
        }
        return result
    }
    init(slots: [TimeSlotDefinition], save: @escaping ([TimeSlotDefinition]) throws -> Void) {
        let rows = slots.map { TimeSlotDraft(section: $0.sectionNumber, start: $0.startMinute, end: $0.endMinute) }
        self.initial = rows; self.save = save; _rows = State(initialValue: rows)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Text("按照学校作息设置每一节课。课程会自动使用这里的开始和结束时间。")
                        .font(AppTypography.body).foregroundStyle(.secondary)
                    ForEach($rows) { $row in
                        EditorGroup("第\(row.section)节") {
                            DatePicker("开始", selection: time($row.start), displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact).accessibilityLabel("第\(row.section)节开始时间")
                            DatePicker("结束", selection: time($row.end), displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact).accessibilityLabel("第\(row.section)节结束时间")
                            Button("移除第\(row.section)节", role: .destructive) {
                                let removedID = row.id
                                rows.removeAll { $0.id == removedID }
                            }
                                .buttonStyle(AppButtonStyle(.destructive))
                        }.appSurface()
                    }
                    Button("添加节次", systemImage: "plus") { add() }
                        .buttonStyle(AppButtonStyle(.secondary)).disabled(rows.count >= 30)
                    Text("已被课程使用的节次不能删除。每节结束时间须晚于开始时间，节次之间不能重叠。")
                        .font(AppTypography.caption).foregroundStyle(.secondary)
                    EditorValidation(messages: issues + (error.map { [$0] } ?? []))
                }.padding(AppSpacing.page)
            }.background(AppColors.canvas)
                // These controls edit wall-clock minutes, never absolute semester dates.
                .environment(\.timeZone, .gmt)
                .navigationTitle("作息时间").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { if rows != initial { exit = true } else { dismiss() } }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { commit() }.disabled(rows.isEmpty || !issues.isEmpty) }
                }
        }.appSheet(expanded: true).modifier(DraftExitModifier(dirty: rows != initial, confirming: $exit) { dismiss() })
    }
    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(get: { Date(timeIntervalSince1970: TimeInterval(minutes.wrappedValue * 60)) },
                set: { date in
                    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .gmt
                    minutes.wrappedValue = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
                })
    }
    private func add() {
        let used = Set(rows.map(\.section))
        guard let section = (1...30).first(where: { !used.contains($0) }) else { return }
        // Editable initial suggestion only; no course uses it until the user saves.
        let start = min((rows.last(where: { $0.section < section })?.end ?? 470) + 10, 1390)
        rows.append(TimeSlotDraft(section: section, start: start, end: min(start + 45, 1439)))
        rows.sort { $0.section < $1.section }
        AppHaptics.selected()
    }
    private func commit() {
        do {
            let values = try rows.map { try $0.definition() }; try TimeSlotDefinition.validate(values)
            try save(values); AppHaptics.success(); dismiss()
        } catch { self.error = "无法保存作息：\(error.localizedDescription)" }
    }
}
