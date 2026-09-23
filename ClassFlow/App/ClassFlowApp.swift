import SwiftUI

@main
@MainActor
struct ClassFlowApp: App {
    @StateObject private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let container = environment.container {
                ClassFlowRootView(container: container)
                    .modelContainer(container)
                    .environmentObject(environment)
                    .onChange(of: scenePhase, initial: true) { _, phase in
                        if phase == .active { environment.refreshCalendars() }
                    }
            } else {
                AppEmptyState(title: "无法打开本地数据",
                    message: (environment.startupError ?? "请重新启动 ClassFlow。") + "\n原有数据未被删除。",
                    symbol: "externaldrive.badge.exclamationmark")
            }
        }
    }
}
