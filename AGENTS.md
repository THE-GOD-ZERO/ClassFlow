# ClassFlow 工程工作约定

- UI 修改前阅读根目录 `DESIGN_SYSTEM.md`，这是后续所有页面的强制设计规范。
- 复用 `ClassFlow/DesignSystem` 的 spacing、radius、typography、colors、motion、haptics 与组件。新增视觉常量先归入对应 token；局部例外必须说明原因。
- 保留原生 NavigationStack/TabView/Sheet/Toolbar；最低 iOS 17。课程名称在大字体列表和详情中完整显示，遵守 Reduce Motion，操作目标至少 44pt。
- 业务通过既有 ScheduleService/ScheduleResolver；UI 不查询 EventKit，不复制调休课程，不在 body 执行复杂布局计算。
- 每阶段严格按用户授权范围工作；不得自动进入下一阶段。修改 Schema、Resolver 或数据语义前确认任务范围。
- 新 UI 要有纯内存 Preview 场景与逐页审查记录。结构检查不能当成编译、渲染或真机验证。
- 文件新增后执行 `node scripts/generate-project.mjs`；运行 `node scripts/verify-structure.mjs` 和 `node scripts/verify-design-system.mjs`。macOS 上运行已有 CI Build/XCTest，Windows 上明确记录尚未真实编译验证。
