import SwiftUI
import SwiftData

@MainActor
struct ClassFlowRootView: View {
    let container: ModelContainer
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(container: container)
                .tabItem { Label("今日", systemImage: "sun.max") }.tag(0)
            WeekScheduleView(container: container)
                .tabItem { Label("课表", systemImage: "calendar") }.tag(1)
            CoursesView(container: container) { selectedTab = 0 }
                .tabItem { Label("课程", systemImage: "books.vertical") }.tag(2)
        }
        .tint(AppColors.accent)
        .onChange(of: selectedTab) { _, _ in AppHaptics.selected() }
    }
}
