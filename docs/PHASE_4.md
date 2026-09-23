# Phase 4 — Course Management & Course Editor

## 范围与验证状态

已实现本阶段课程管理代码，保持 iOS 17、原生 SwiftUI 与既有 Design System。未进入 Phase 5。未新增完整 Settings、通知、Widget、iCloud 或后端。

Windows 已运行工程生成、结构验证、设计规范验证。没有 Swift/Xcode；没有进行 Xcode Build、XCTest、SwiftUI Preview、Simulator 或真机测试。当前目录不是 Git 仓库，macOS CI **未运行，尚未真实编译验证**。以下 UI 评价均为源码审查，不代表渲染或体验验收。

## 文件清单

新增：

- `ClassFlow/Core/Courses/CourseDraft.swift`：课程/安排草稿、验证、转换、排序和自动颜色。
- `ClassFlow/Core/Courses/ActiveWeeksFormatter.swift`：周数组的统一展示。
- `ClassFlow/Core/Courses/CourseConflictChecker.swift`：循环安排的真实交集。
- `ClassFlow/Services/Courses/CourseRepository.swift`：保存、删除、作息写入及失败回滚。
- `ClassFlow/Services/Courses/CoursesViewModel.swift`：当前学期列表与搜索。
- `ClassFlow/Components/CourseEditorComponents.swift`：分组、安排摘要、验证提示。
- `ClassFlow/Components/DraftDismissGuard.swift`：未保存修改的取消/下拉保护。
- `ClassFlow/Views/Courses/CoursesView.swift`：列表、行、功能入口和 SwiftData 交互接线。
- `ClassFlow/Views/Courses/CourseManagementDetail.swift`：完整安排与编辑/删除入口。
- `ClassFlow/Views/Courses/CourseEditor.swift`：新建/编辑共用界面。
- `ClassFlow/Views/Courses/CourseScheduleEditor.swift`：独立安排草稿 Sheet。
- `ClassFlow/Views/Courses/WeekSelector.swift`：教学周网格与快捷操作。
- `ClassFlow/Views/Courses/CourseConflictSheet.swift`：确认冲突。
- `ClassFlow/Views/Courses/TimeSlotEditor.swift`：真实学校作息配置。
- `ClassFlow/Views/Courses/CoursesPreviewData.swift`：21 个纯内存 Preview 场景。
- `Tests/CoreTests/CourseEditingTests.swift`：36 个测试方法。
- `Tests/IntegrationTests/CourseRepositoryTests.swift`：18 个测试方法。
- 本交付记录。
- `docs/phase4-verification.json`：测试定义数、运行限制和关键文件当前 SHA-256 清单（不是运行验证证明）。

修改：

- `ClassFlow/App/ClassFlowRootView.swift`：第三项 Courses Tab，无 Settings 占位。
- `ClassFlow/Core/Schedule/ScheduleDefinitions.swift`：启用既有色板的另外 4 个颜色枚举值。
- `ClassFlow/DesignSystem/AppColors.swift`：10 色映射与中文名称。
- `ClassFlow/DesignSystem/AppComponents.swift`：编辑 Sheet 默认 large 的公共选项。
- `ClassFlow/Views/Schedule/WeekCourseViews.swift`：详情教学周改用公共 formatter。
- `ClassFlow.xcodeproj/project.pbxproj` 与共享 Scheme：生成器再生成，新增文件自动进入正确 Target。
- `DESIGN_SYSTEM.md`、`README.md`：本阶段规范与使用说明。

未修改五个 SwiftData Model、Schema V1、关系或 Delete Rule、ScheduleResolver、CalendarService/SyncService、原 135 个测试方法、CI Build/Test 步骤。

## 数据与保存

CourseDraft / CourseScheduleDraft 为值类型，不持久化。打开编辑器时复制已有定义，包括课程与安排 ID。安排 Sheet 再使用独立草稿，完成后才合并到课程草稿；课程保存之前所有更改都未进入数据库。清空最后一条安排允许临时编辑，但禁止最终保存。

CourseRepository 在主线程独立 ModelContext 中关闭自动保存，重新检查当前学期、节次、周数、重复安排和冲突。编辑使用原始草稿进行过期检查；外部数据已变则要求重新打开，避免覆盖。新建仅插入新模型；编辑按原 ID 更新，保留未删除安排的 ID；移除安排仅删除相应 CourseSchedule。Course 删除使用既有 cascade 清理所有关联安排，不删除学期、作息、特殊规则。写入失败 rollback。

保存/删除后发出既有 `scheduleDataDidChange()`：Today 和 Schedule 沿用各自 ViewModel → ScheduleService → ScheduleResolver 重载。Courses 使用值快照供显示和编辑，不维护独立持久化课程库。Override 不写入；周日补周一继续按真实日的教学周查询最新周一课程。

颜色仍保存在已有 `colorRawValue` 字符串中，不涉及 Schema 迁移。保留原 6 个键，增加 plum/clay/olive/denim。自动颜色选当前学期使用最少的色，平局依色板顺序。旧版会把新增颜色回退为蓝色，回退版本编辑可能丢失该色。

## 周数与冲突

WeekSelector 的总周数取 Semester.totalWeeks，全部/单双周复用 ActiveWeeks；任意点击形成 Set<Int>，最终写入既有整数数组。连续区间可用起止周应用，结束不会早于开始。ActiveWeeksFormatter 去重排序、合并相邻周，匹配完整学期的单/双周才显示相应简称，无重复字符串数据源。

只有星期相同、节次闭区间重叠、activeWeeks 有交集才报告冲突。不同星期、相邻不重叠节次、单双周或不相交周段不冲突。排除存储中的自身旧版本，同时检查同一草稿内部安排。完全相同星期/节次/周集合属于重复安排，即使教室不同也禁止保存。

安排完成时展示涉及该安排的冲突；最终写入再次查询最新数据检查。确认信息包含另一课程、相交节次、实际相交周；“返回修改”和“仍然保存”均非危险动作。仅接受用户看过的具体冲突，冲突范围变化需要再次确认。

## 逐页 UI 源码审查

| 页面 | 已做源码检查 | 待设备检查 |
| --- | --- | --- |
| Courses | 色条、完整名称、教师与安排数、默认地点、前两条安排和剩余数；稳定 Course ID；原生 searchable；长按编辑/删除，详情中也可操作；无学期/无作息/无课程/搜索无结果各有说明 | 小屏与最大字号的滚动、VoiceOver 合并阅读、搜索键盘和列表插入/删除动画 |
| Course Detail | 紧凑标题与色标；完整教师、地点、全部安排、周数、备注；明确编辑和危险删除；无卡片嵌套 | 长地点与英文名称、系统 Sheet 层次 |
| Course Editor | 基本信息/安排分组；色板与备注渐进展开；保存有效性与错误文字；名称多行；FocusState、键盘完成和滚动收键盘 | 编辑中下拉尝试→放弃确认、反复打开嵌套 Sheet、键盘遮挡和最大字号 |
| Schedule Editor | 星期和起止节次系统 Picker；根据 ClassTimeSlot 展示时段；地点继承说明；独立草稿；重复安排禁止完成 | Picker 长文字、安排完成后的返回动作与触觉 |
| Week Selector | >=44pt 且随字号扩大的网格；快捷操作可纵向降级；VoiceOver 读“第 X 周，已/未选择”；区间渐进展开 | 104 周与最大字号滚动、选择状态的高对比可读性 |
| Conflict Sheet | 交集信息完整换行；“仍然保存”使用 secondary；外层保留原草稿；确认 Sheet 消失后再提交 | 连续确认/返回与外层自动关闭时序 |
| Time Slots | 开始/结束系统时间选择；固定 GMT 仅用于墙上时间分钟编辑，与实际日期无关；可补回中间节次；重叠/反向即时提示；禁止删除被引用节次 | 12/30 节操作效率，12/24 小时系统格式与辅助字体 |
| Today / Schedule | 继续观察已有 revision，Resolver 和布局算法未改变；详情只替换周数字符串格式化 | 创建、编辑、删除后跨 Tab 即时结果及调休映射回归 |

所有新增界面使用 AppSpacing / AppTypography / AppRadius / AppColors。无固定课程行高度；名称与详情允许全文换行，使用深浅色独立 accent + 系统正文。颜色选择有中文 VoiceOver 标签和选择值。按压、选择和数据插入/删除复用 AppMotion，Reduce Motion 不使用缩放/位移；成功保存才 success，删除成功 warning；不在滚动或 body 创建 haptic。

取消保护使用系统 `interactiveDismissDisabled` 与轻量 UIKit 适配器监听尝试关闭，并转发原有 dismiss 生命周期。依据 [Apple 的尝试关闭回调](https://developer.apple.com/documentation/uikit/uiadaptivepresentationcontrollerdelegate/presentationcontrollerdidattempttodismiss(_:))；UIKit/SwiftUI 桥接仍需要 iOS 17 和当前系统实测，不以静态检查替代。

## 性能与测试

课程列表使用 LazyVStack 和稳定 UUID；教学周用 LazyVGrid。没有新增计时器、GeometryReader、Blur、AnyView、View 中 EventKit 或逐字输入时解析全学期。搜索仅当前学期快照，冲突仅在安排完成/最终保存时执行；重复与基础字段验证只针对当前草稿。

保留原 135 个 XCTest 方法。新增 **54 个**（36 Core + 18 SwiftData/联动），当前共定义 **189 个**。涵盖草稿转换与取消、校验边界、排序、周数与格式化、冲突与排除自身、自动颜色、ID 保留、添加/删除子安排、级联删除、错误回滚、冲突确认变化、过期写入、搜索、作息和调休读取编辑结果。**均未在本 Windows 会话执行。**

Windows 实际执行：`node scripts/generate-project.mjs`、`node scripts/verify-structure.mjs`、`node scripts/verify-design-system.mjs`。结构检查覆盖工程引用、文件分隔符、业务边界、原有 CI 标记、Preview 和 XCTest 数量；设计检查覆盖 token 使用和参考色板对比度。它们不验证 Swift 类型系统、SwiftData 运行时或实际视觉。

## 剩余验收与下一步

1. 推送后让已有 macOS CI 运行真实 unsigned Simulator Build、Core tests 与 XCTest，任何失败必须修复。
2. Simulator 检查 iOS 17 的嵌套 Sheet/取消保护、键盘和最大辅助字号；真机验收 haptic、VoiceOver、深色与大量课程滚动。
3. 用一份真实学期课表完成 UI 录入→Today/周课表→编辑→调休→删除的回归。当前作息以课程管理必需 Sheet 提供，完整 Settings 不在本阶段。
4. 完成本阶段运行验收后，再由用户授权 Phase 5 日历完整同步。当前停止，不自动推进。
