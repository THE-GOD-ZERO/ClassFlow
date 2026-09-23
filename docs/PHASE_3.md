# 第三阶段验收记录

日期：2026-09-23。开发环境：Windows。本阶段只实现 Schedule 周课表及必要公共组件，没有开发完整课程编辑器、通知、Widget 或云同步。

## 数据与渲染流程

```text
SwiftData 当前学期
  → WeekScheduleService（计算目标周的七个真实日期）
  → ScheduleService / ScheduleResolver（逐日解析）
  → DayScheduleSnapshot / WeekScheduleSnapshot
  → CourseLayoutEngine（节次位置、连续高度、冲突 lane）
  → WeekScheduleViewModel（一次生成页面状态）
  → WeekSchedulePageView（只渲染快照）
```

真实日期、真实星期、有效星期和实际教学周分别保存。`replacementWeekday` 只改变课程筛选用的星期，`activeWeeks` 仍使用真实日期所在教学周。节假日列不含普通课程；未确认调休列保持为空并提供选择 Sheet；确认逻辑与 Today 共用 `ScheduleOverrideService`。

## 页面能力

- 显示教学周、周日期范围、周一至周日具体日期，以及上一周、下一周和回到本周。
- 日期头和课程内容位于同一个横向 ScrollView，整体网格可纵向滚动。
- 节次和时间来自任意数量的 `ClassTimeSlot`；统一视觉高度集中在 `ScheduleLayoutMetrics`。
- 多节课程是一张连续卡片。完全或部分重叠课程横向分栏，连续且不重叠的课程保持全宽。
- 当前日期使用小范围 Accent 标记；当前时间线按分钟更新，作息范围外隐藏。
- 节假日、调休、学校安排和待确认调休使用简短列标记；点击普通日期查看完整信息。
- 点击课程打开只读详情，显示名称、教师、地点、实际时间、节次、教学周和备注。
- 16 个纯内存 Preview 覆盖课程密度、单双周、自定义周、冲突、多节课、特殊日期、深色、小屏和大字体，不创建 SwiftData 容器。

## 测试与验证边界

第三阶段新增 42 个 XCTest 方法，项目合计 135 个。新增覆盖周首尾与导航、日期映射、午夜跟随当前周、周数过滤、特殊日期优先级、跨月跨年、学期中途开学、替换星期不改变教学周、布局高度与偏移、两/三门冲突、lane 复用、作息修改、当前时间线、ViewModel 状态及确认后不复制课程。

Windows 上运行了 Node 工程生成器和跨平台结构验证器。验证器检查工程文件引用、分隔符、Core/View 边界、Schedule 的统一入口、Preview 数量、CI 关键步骤和测试清单。它不是 Swift 编译器。

本地没有 Swift、Xcode 或 Simulator，仓库也未连接可用的 GitHub 远程，因此 macOS CI 尚未实际运行。Swift 类型检查、SwiftUI Preview、SwiftData 运行行为、全部 XCTest 和 Simulator 布局仍需首次 GitHub Actions macOS 运行验证。
