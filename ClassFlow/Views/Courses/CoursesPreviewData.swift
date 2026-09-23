import SwiftUI
import ClassFlowCore

#if DEBUG
// Value-only fixtures. No ModelContainer, disk writes, EventKit or production environment.
enum CoursesPreviewData {
    static func page(count: Int = 10, longText: Bool = false) throws -> CoursesPageModel {
        let slots = try (1...12).map {
            try TimeSlotDefinition(sectionNumber: $0, startMinute: 480 + ($0 - 1) * 60, endMinute: 525 + ($0 - 1) * 60)
        }
        let courses = (0..<count).map { index in
            CourseDraft(name: longText ? "大学英语（学术写作与跨文化交流）Advanced Academic Writing and Intercultural Communication" : ["高等数学", "有机化学实验", "Academic Writing"][index % 3],
                teacher: longText ? "王老师 / Professor Alexandra Montgomery" : "王老师",
                location: longText ? "实验中心北区综合教学大楼 B2-104 阶梯教室" : "A301",
                color: CourseColor.allCases[index % CourseColor.allCases.count], note: "实验课记得带实验服。教材第 3 版。",
                schedules: (0..<(index % 4 + 1)).map { n in
                    CourseScheduleDraft(weekday: n + 1, startSection: n * 2 + 1, endSection: n * 2 + 2,
                        activeWeeks: index % 3 == 0 ? Set(1...18) : (index % 3 == 1 ? Set([1, 3, 5, 7, 9, 11, 13, 15, 17]) : Set([1, 2, 3, 5, 7, 9, 12])),
                        location: n == 0 ? "" : "B205")
                })
        }
        return CoursesPageModel(semesterID: UUID(), semesterName: "2026–2027 第一学期", totalWeeks: 18, slots: slots, courses: courses)
    }
}

@MainActor
private struct CoursesPreviewHost: View {
    var count = 10
    var longText = false
    var mode = "list"
    var body: some View {
        if let page = try? CoursesPreviewData.page(count: count, longText: longText) {
            if mode == "create" {
                CourseEditor(draft: CourseDraft(color: .clay), original: nil, page: page) { _, _ in }
            } else if let course = page.courses.last, mode == "edit" {
                CourseEditor(draft: course, original: course, page: page) { _, _ in }
            } else if let course = page.courses.last, mode == "detail" {
                CourseManagementDetail(course: course, page: page, save: { draft, _, _ in draft }, delete: { _ in })
            } else if let course = page.courses.last, let schedule = course.schedules.first, mode == "schedule" {
                CourseScheduleEditor(schedule: schedule, parent: course, page: page) { _, _ in }
            } else if let course = page.courses.first, mode == "conflict" {
                CourseConflictSheet(courseName: course.name,
                    conflicts: CourseConflictChecker.conflicts(for: course, among: page.courses), returnToEditing: {}, accept: {})
            } else if mode == "times" {
                TimeSlotEditor(slots: page.slots) { _ in }
            } else {
                NavigationStack {
                    CoursesPageView(page: mode == "noSemester" ? nil : page, courses: page.courses,
                        searching: false, error: nil, add: {}, configureTimes: {}, setupSemester: {}, open: { _ in }, edit: { _ in }, delete: { _ in })
                        .navigationTitle("课程")
                }
            }
        } else { Text("预览数据无效") }
    }
}

@MainActor
private struct WeekSelectorPreviewHost: View {
    @State var weeks: Set<Int>
    var body: some View {
        ScrollView { WeekSelector(selection: $weeks, totalWeeks: 18).padding(AppSpacing.page) }
            .background(AppColors.canvas)
    }
}

#Preview("Courses · 空状态") { CoursesPreviewHost(count: 0) }
#Preview("Courses · 无学期") { CoursesPreviewHost(mode: "noSemester") }
#Preview("Courses · 1 门 / 1 个安排") { CoursesPreviewHost(count: 1) }
#Preview("Courses · 10 门 / 中英文") { CoursesPreviewHost() }
#Preview("Courses · 长文字") { CoursesPreviewHost(count: 1, longText: true) }
#Preview("Detail · 4 个安排") { CoursesPreviewHost(count: 4, mode: "detail") }
#Preview("Create Editor") { CoursesPreviewHost(mode: "create") }
#Preview("Edit Editor") { CoursesPreviewHost(count: 4, mode: "edit") }
#Preview("Schedule Editor") { CoursesPreviewHost(count: 1, mode: "schedule") }
#Preview("教学周 · 单周") { WeekSelectorPreviewHost(weeks: Set(stride(from: 1, through: 18, by: 2))) }
#Preview("教学周 · 双周") { WeekSelectorPreviewHost(weeks: Set(stride(from: 2, through: 18, by: 2))) }
#Preview("教学周 · 自定义") { WeekSelectorPreviewHost(weeks: [1, 2, 3, 5, 7, 9, 12]) }
#Preview("课程冲突确认") { CoursesPreviewHost(mode: "conflict") }
#Preview("作息编辑") { CoursesPreviewHost(mode: "times") }
#Preview("Courses · Dark") { CoursesPreviewHost().preferredColorScheme(.dark) }
#Preview("Editor · Dark") { CoursesPreviewHost(mode: "edit").preferredColorScheme(.dark) }
#Preview("Courses · 小屏", traits: .fixedLayout(width: 320, height: 568)) { CoursesPreviewHost(longText: true) }
#Preview("Courses · 最大字体") { CoursesPreviewHost(longText: true).environment(\.dynamicTypeSize, .accessibility5) }
#Preview("Editor · 最大字体") { CoursesPreviewHost(longText: true, mode: "edit").environment(\.dynamicTypeSize, .accessibility5) }
#Preview("教学周 · 最大字体") { WeekSelectorPreviewHost(weeks: [1, 3]).environment(\.dynamicTypeSize, .accessibility5) }
#Preview("Reduce Motion · 高对比") {
    CoursesPreviewHost().environment(\.accessibilityReduceMotion, true).environment(\.colorSchemeContrast, .increased)
}
#endif
