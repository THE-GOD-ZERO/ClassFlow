# 第二阶段验收记录

日期：2026-09-22。开发环境：Windows。此阶段只实现 Today 与自动化验证配置，没有开发完整周课表、课程编辑、通知或 Widget。

## Today 数据流

```text
SwiftData Semester / Course / TimeSlot / Override
  → ScheduleService
  → ScheduleResolver（教学周、规则优先级、effectiveWeekday、真实上课时间）
  → TodaySnapshotBuilder（finished/current/next/upcoming、分钟倒计时）
  → TodayViewModel（加载、午夜/前台刷新、用户确认写入）
  → TodayView（纯展示和 Sheet 交互）
```

Today 没有自行计算星期或筛选 CourseSchedule。教师信息补入既有 `CourseOccurrence` 值类型，不修改 SwiftData Schema。课程起止时间继续由第一阶段 Resolver 使用首节开始与末节结束计算。

未确认调休是有意的双层行为：通用 Resolver 保留实际星期的临时预览，TodaySnapshotBuilder 在 `needsConfirmation` 时隐藏所有课程，避免首页把预览误当成确定课表。用户从原生 Sheet 选择星期后，写入同日的手动 `ScheduleOverride`；手动规则优先级最高，原课程和 CourseSchedule 数量不变。

## 页面状态

- 顶部显示民用日期、真实星期、教学周和当前学期名称。
- 当前课程优先于下一节课程；主卡显示完整时间、地点、教师与分钟级倒计时。
- 今日列表按时间排序，以文字和 SF Symbol 同时区分已结束、进行中、下一节和稍后。
- 节假日只显示放假状态，不显示普通课程。
- 已确认调休显示“今日按星期 X 课表”；学校规则显示“学校特殊安排”。
- 未确认调休显示选择入口，确认前不展示猜测课程。
- 无学期时提供最小的学期创建 Sheet；无课程、学期前、学期后都有独立空状态。
- 使用系统字体、Material、语义颜色和 `ViewThatFits`，没有固定内容高度，支持深浅色与 Dynamic Type 的布局适配。
- 分钟任务只在 Today 可见且 App active 时运行；回到前台立即重算，跨午夜会重新调用 ScheduleService。

## Preview 与测试

Preview 数据是纯值类型，不创建 ModelContainer，不会污染真实 SwiftData。覆盖普通有课、正在上课、下一节、无课、节假日、按星期一调休、未确认调休和无学期。

第二阶段新增 30 个测试方法，项目现有共 93 个 XCTest 方法。新增测试覆盖排序、状态边界、倒计时、跨节次、教师、调休映射、学校/手动优先级、未确认隐藏、教学周、单双周、学期前后、无学期、无课程、午夜刷新、确认规则持久化和不复制课程。

## macOS CI

`.github/workflows/ios-ci.yml` 在 push、pull request 和手动触发时运行。它：

1. 打印 macOS、Xcode、Swift、runtime 和可用设备。
2. 自动发现顶层 workspace/project，通过 `xcodebuild -list -json` 验证并选择共享 Scheme。
3. 运行 `swift test --parallel`。
4. 对 generic iOS Simulator 执行无签名 `xcodebuild clean build`。
5. 从 `simctl` JSON 动态选择实际存在的 iPhone Simulator，启动后执行 XCTest。
6. 保留真实失败状态，并在可用时上传 `.xcresult`。

CI 不包含证书、Provisioning Profile、真机安装或发布。

## 当前验证边界

Windows 上只执行工程引用、文件覆盖、权限文件、模块边界、分隔符、禁用危险强制操作和 CI 配置静态检查。未声称完成 Swift 编译、宏展开、SwiftUI Preview、Simulator、EventKit 或 SwiftData iOS 运行验证。

必须由首次 macOS CI 确认：Swift/Xcode SDK 类型检查、SwiftData 关系与查询运行、所有 XCTest、Preview 宏展开、SwiftUI 在实际尺寸/深浅色/大字体下的结果，以及 Simulator 启动兼容性。EventKit 授权和时区行为最终仍需真机验证。

本阶段完成后停止，下一阶段 Schedule 周课表尚未开始。
