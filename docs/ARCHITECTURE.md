# 第一阶段架构

## 模型与所有权

```text
Semester
 ├─ courses ──cascade──> Course
 │                       └─ schedules ──cascade──> CourseSchedule
 ├─ timeSlots ──cascade──> ClassTimeSlot
 └─ overrides ──cascade──> ScheduleOverride
```

每条子记录只属于一个父对象。反向关系明确写在拥有者的 `@Relationship` 上；子对象的父引用为 Optional，以适配删除过程中 SwiftData 的关系置空。构造子对象必须传父对象。课程与具体上课安排分离，调休始终使用日期规则查询原课程，没有复制课程的路径。

这些级联规则依据 [Apple SwiftData 关系说明](https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes/)。实际宏展开、关系反向更新和级联行为仍需运行本项目的集成测试验证。

- `Semester`：UUID、名称、`startDayKey`、总周数、学校时区、当前学期标记、备注。`startDate` 为学校时区内的派生 Date，供以后 DatePicker 使用。使用 Repository 保持至多一个当前学期。
- `Course`：UUID、名称、教师、默认教室、语义颜色键、备注、所属学期。
- `CourseSchedule`：UUID、星期、起止节次、排序去重的 `[Int]` 有效周数、可选教室覆盖、所属课程。一次转换为 `ActiveWeeks` 后使用集合查找。修改学期长度不自动截断已有周数。
- `ClassTimeSlot`：UUID、节次、起止分钟数、所属学期。分钟数表示学校当地的时钟时间，不附带虚构日期。暂不支持跨午夜的一节课。
- `ScheduleOverride`：UUID、学期、日期键、类型、替换星期、来源、确认状态、标题和备注、更新时间。自动导入另存唯一同步键、日历 ID、事件 ID、来源指纹。手动记录始终独立于自动记录。

作息表按学期归属，便于保留历史学期。修改时间只更新作息，不修改 CourseSchedule；移除仍被引用的节次会失败。重复节次、时间倒置、节次时间重叠会被拒绝。不同课程冲突会返回给调用方，由未来界面展示，不会悄悄删课。

容器显式关闭 CloudKit。Schema 版本从 V1 开始；未来有持久化字段变化时必须保留旧版模型定义并提供新版本迁移，不能直接改 V1 后假装兼容。UUID 和唯一键当前服务于本地存储，未来启用 CloudKit 时需要专门迁移与唯一性策略验证。

## 日期与教学周

`LocalDay` 采用公历的 `yyyy-MM-dd` 日期键，不使用 Date 的精确相等判断某一天。学校时区默认 `Asia/Shanghai`，保存在 Semester 中；设备旅行切换时区不会移动已保存的开学日、调休日或学校课程时间。

教学周按周一至周日计算。开学日所在周为第 1 周；如果周三开学，第 1 周只有周三起生效，周一、周二仍是学期前。学期截止于第 N 周后的周一（不含该日）。跨周调休使用**实际日期所在教学周**，只替换 weekday。需要执行别的教学周课程的学校安排超出第一阶段规则能力，未来应显式增加 replacementWeek，而不能隐含推断。

民用日期加减使用公历日历算法；不把一天当作固定 86,400 秒。课程起止时间按学校时区还原成 Date。夏令时跳过的本地时间会产生诊断，不自动移至另一日；重复时间选择第一次出现。不存在的整天（极端时区变更）返回日期错误。

## 唯一课表解析入口

`ScheduleService` 将 SwiftData 模型转换为值类型，再交给 `ScheduleResolver`。核心模块只依赖 Foundation，未来 Widget 和通知可以使用同一解析器。

优先级从高到低：

1. 已确认的手动特殊规则。
2. 学校来源的明确且已确认规则，包括明确“正常上课”。
3. 已确认、含替换星期的其他调休映射。
4. 未知映射的调休候选：保留待确认状态，避免同日国家放假记录将提醒吞掉。
5. 系统识别的确定节假日。
6. 普通周课表。

同级冲突按更新时间、UUID 稳定选取一个用于展示，同时返回 `conflictingOverrides` 和 `needsConfirmation`，不可当作确定结果。放假屏蔽课程。学期外日期仍可返回特殊日期信息，但绝不会生成课程。

无映射的调休日返回 `needsConfirmation = true`，课程暂按实际星期提供**待确认预览**。未来 UI 必须醒目标明不确定状态；未来通知不得为待确认结果排程。确认后持久化星期映射，再走同一个解析器。

解析结果含实际日期、教学周状态、有效星期、选中的规则、课程实际起止时间、冲突、缺失节次与无效当地时间诊断。单门课的 occurrence ID 由实际日期和 CourseSchedule ID 组成，适合后续通知去重。

## 系统日历进入课表的数据流

```text
用户选择的系统日历
  → CalendarService / EventKit
  → CalendarEventSnapshot（值类型）
  → CalendarEventParser
  → ImportedOverride（日期、来源、同步键、指纹）
  → CalendarSyncService / SwiftData ScheduleOverride
  → ScheduleService / ScheduleResolver
  → 后续 Today、Schedule、通知
```

CalendarService 是唯一创建和查询 EKEventStore 的位置，Views 不依赖 EventKit。iOS 17 使用 `requestFullAccessToEvents()` 和 `NSCalendarsFullAccessUsageDescription`，因为需要读取已有事件；见 [Apple EventKit 权限迁移说明](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels)。虽然系统权限名称叫 Full Access，本实现不写入系统日历。

每次同步重新查询授权状态。未请求、已拒绝、系统限制和只有写入权限均不查询事件。读取失败不删除旧数据；明确撤销授权时删除该学期自动导入规则，保留手动规则、学期和原课程。自动记录上的确认跟随其来源记录；如果需要独立于来源长期保留，使用手动规则。

选择列表按学期持久化为日历 ID → 来源角色（节假日/学校），默认不选择任何日历。名称匹配只用于提供学校日历候选，不自动授予可信来源角色。每个日历指定一个角色，可选多个日历。来源选择 UI 留到第五/七阶段。

App 启动与回到前台触发检查；监听 `EKEventStoreChanged` 并做短时合并。只在有当前学期时进行完整学期扫描，且没有从 View.body 扫描。该通知表示先前事件对象可能失效，因此每次重新取快照，参见 [Apple 事件变更通知说明](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/ekeventstorechanged)。目前没有后台持续运行或后台刷新承诺。

## 保守解析与幂等

- 第一阶段仅解析全天事件；不会把一个时段的会议当成整天放假。
- 命中七个节日的完整名称，或明确的少量“放假/休”标题变体时，识别事件覆盖的日期，不自行扩大为国家完整假期。
- 包含“调休/上班/补班/补课/调课”的候选，默认没有替换星期且待确认。
- 仅学校来源可解析“按周一课表上课”“执行星期五课表”“补周三课程”等明确语句；多星期冲突保留待确认。
- 存在否定、取消、可能、待定等措辞时不自动识别。带日期的映射须与事件日期一致；多日映射事件或不支持的数字日期格式交给确认。复杂校历表述留待第五阶段扩展。
- 全天事件的结束日期是排他的。使用快照记录的时区解释民用日期；EventKit 的浮动事件由适配层记录读取时的系统默认时区，再归一化为 LocalDay，不能直接当成上海时区的午夜。此处理依据 [Apple 的 startDate 说明](https://developer.apple.com/documentation/eventkit/ekevent/startdate)。读取时扩大绝对时间窗口后按民用日期裁剪；核心解析器对其他未提供时区的快照才回退到学校时区。
- 同步键包含学期 ID、日历 ID、事件 ID、事件起始民用日期、规则日期，使用长度前缀避免分隔符碰撞。不同学期和重复事件实例不会共用一条记录。
- 来源指纹包含正文和解析相关字段。重复扫描同内容不新增、不覆盖确认；来源内容变化时重新解析、清除旧确认。冲突的重复来源快照会使整次扫描失败。
- 读取和解析完成后才开始修改，在独立 ModelContext 中统一保存，失败时 rollback。完整学期快照会清理源事件删除、日期移动、来源取消选择、日历删除以及学期范围修改留下的自动旧记录。手动记录不参与自动清理。

首版不会把年节名称等同于可靠的国家调休数据来源。系统没有订阅中国节假日或学校校历时，普通课表仍可计算；第五阶段需要让用户明确看到“未选择来源/未发现规则”等状态。

## Today 状态层

`TodaySnapshotBuilder` 位于纯 Foundation 核心包。它只接受 `ResolvedDay`，按 `start <= now < end` 识别当前课程，并把最早的 `start > now` 课程标为下一节；结束边界属于 finished。倒计时向上取整到分钟。即使课程重叠，也由 Resolver 返回冲突诊断，Today 只稳定选最早一条作为主卡，不改动数据。

`TodayViewModel` 是 SwiftData 与 SwiftUI 之间的页面协调层。它读取当前学期，通过 ScheduleService 调用唯一 Resolver，再生成不可变 TodaySnapshot。每分钟只重算时间状态；跨民用日期、App 回到前台或日历同步版本变化时重新解析整天。View 不直接读取 weekday、筛选课程或处理覆盖优先级。

通用 Resolver 为未知调休保留实际星期的临时课程，以便其他消费者显示预览；Today 明确选择更保守的产品策略：`needsConfirmation` 时课程数组为空。用户选定星期后写入手动规则，随后重新运行 Resolver。这样课程实体始终只保留原星期数据。

## Schedule 周状态与布局层

`WeekScheduleService` 根据正在查看的教学周计算该周周一，并把七个真实 `LocalDay` 分别交给既有 `ScheduleService`。`DayScheduleSnapshot` 同时保存真实星期和 Resolver 给出的有效星期；`academicWeek` 始终来自真实日期。调休只改变有效星期，因此第 6 周周日补周一课程时仍使用第 6 周检查 `activeWeeks`。

`WeekScheduleViewModel` 一次读取当前学期与作息，生成一个 `WeekScheduleSnapshot` 和一组 `CourseLayoutItem`。SwiftUI body 不查询 SwiftData、不调用 EventKit、不执行覆盖优先级或冲突计算。切换周只生成目标周，不预加载整个学期。Today 与 Schedule 的调休确认共用 `ScheduleOverrideService`，写入一条高优先级手动规则后重新解析，不复制 Course 或 CourseSchedule。

`CourseLayoutEngine` 采用统一视觉节次高度，实际时间文字仍来自 `ClassTimeSlot`。起止节次先映射为作息数组下标，一门跨多节课程只产生一张卡。相交区间形成冲突组，再以稳定的贪心算法分配横向 lane；只有上一张课程的结束节次严格早于下一张开始节次时才能复用 lane，因此 1–2 节与 2–3 节会并排，1–2 节与 3–4 节不会。

日期标题、节次栏和课程网格放在同一个横向滚动内容中，确保标题与课程同步。外层纵向滚动承载完整网格。本阶段保留按钮切周，没有叠加整页横扫手势，以避免和横向课表滚动冲突。当前时间线按分钟更新，仅在当前查看周且时间落在作息区间内显示。
