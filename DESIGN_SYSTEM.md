# ClassFlow Design System · Phase 4

本规范是后续页面的强制验收依据。最低 iOS 17。视觉目标：安静、清晰、有个人气质的原生时间工具。信息密度来自层级与对齐，不靠压小字体。2026-09-23 根据官方产品资料提取原则；未复制资产、截图或完整布局，未声称实机体验这些产品。

## 参考 → 可执行决策

| 参考 | 提取原则 | ClassFlow 实现 |
| --- | --- | --- |
| [Things 3](https://culturedcode.com/things/features/) | 内容分组、渐进呈现细节、轻量交互 | Today 仅一个 Hero；普通课程为轻量行，细节进入系统 Sheet |
| [Structured](https://help.structured.app/en/articles/380546) | 以一天的时间顺序组织任务 | 固定“课程名→时间→地点”阅读顺序；日/周共用颜色和文本样式 |
| [Fantastical](https://flexibits.com/fantastical-ios/help/calendar-views) | 日历与事件列表提供不同密度的视角 | 网格与完整课程列表共享快照；日期可展开说明，特殊状态用小型标签 |
| [Apple Calendar](https://support.apple.com/en-ie/guide/iphone/iphfd1054569/ios) | 根据任务选择日历视图 | 日期上下文始终可见，原生导航与周切换按钮 |
| [Apple Reminders](https://support.apple.com/en-ae/119953) | 分组、列表与状态标记 | 清晰标题、局部色标、文本状态；不依赖颜色表达状态 |
| [Apple Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | 可读性、可操作性与辅助技术 | 动态文字、44pt 操作区、VoiceOver、Reduce Motion |

上表后两列是本项目设计判断，不是对参考 App 内部实现的断言。

## 字体

全部为系统 Dynamic Type 字体。`AppTypography`：largeTitle（largeTitle/semibold）、pageTitle（title2/semibold）、sectionTitle（title3/semibold）、courseTitle（headline/semibold）、body、secondary（subheadline）、caption、micro（caption2），gridTitle（caption/semibold）。避免连续大面积 bold。核心课程名在 Today、列表和详情完整换行，禁止 minimumScaleFactor 压小文字。

## 间距与圆角

`AppSpacing`：2/4/8/12/16/24/32，页面水平留白 20，最小独立触控目标 44。零间距可用于对齐网格。`AppRadius`：small 10（紧凑卡片/按钮）、medium 16（内容表面）、large 22（Sheet/空状态符号容器）。标签使用 Capsule。

课表节高、列宽由既有 `ScheduleLayoutMetrics` 管理，保留统一计算及测试，不在 UI 重新布局。网格细线和色条使用 AppSpacing；预览设备尺寸、日期数字、业务节次不是视觉 token。

## 表面、卡片与颜色

- 主背景 systemGroupedBackground，卡片 secondarySystemGroupedBackground，嵌入区域 tertiarySystemGroupedBackground。正文 primary，次要信息 secondary。
- Hero：实色表面、细课程色条、完整名称、当前/下一节状态与倒计时。列表行无独立背景，轻分隔线。网格卡用轻 tint 与色条。
- 浮动层可使用系统材质；内容层不用 Blur、阴影或大面积 Material。当前不自绘玻璃导航。
- `CourseAccent` 10 色：slate、teal、sage、ochre、rose、iris、plum、clay、olive、denim。仅色板文件允许定制 RGB，每色有独立深/浅色值。文字优先使用语义 primary。
- 原有 CourseColor 的 6 个持久化键保持原样，Phase 4 启用 plum/clay/olive/denim，全部使用现有字符串字段，不改变 Schema。Phase 4.5 将未知键与显示 fallback 分离：读取可显示蓝色，保存其他字段保留原键，主动选色才替换。旧版本不具备此保留保护，不建议回退编辑。
- `AppTag` 统一表现状态，必须含可读文字；今天日期只局部 tint，不染整列。警告不使用颜色作为唯一提示。

## 页面与导航

Today：日期/星期/周 → 当前或下一节 Hero → 今日课程 → 次级特殊说明；顶部保留特殊日期标签，未确认调休单独显示操作入口。

Schedule：周标题与日期范围 → 44pt 前后/本周操作 → 同步滚动日期头和网格。系统 Toolbar 可切换完整列表。Accessibility 字号或冲突导致卡片宽度不足 44pt 时使用按日列表，复用原快照、不改变课程结果。网格允许名称有限行；列表/详情必须保留全文。

当前 Tab 顺序为 Today / Schedule / Courses。Settings 完成后再加入，不放置无效导航。使用原生 TabView、NavigationStack、Toolbar、Sheet，保留系统转场。iOS 26 由新 SDK/系统决定原生导航外观，无仅 iOS 26 可用 API，最低版本不变。

## 按钮与 Sheet

`AppButtonStyle` 提供 primary/secondary/tertiary/destructive/icon/floating。Primary 仅用于保存/创建/继续；导航用 icon/tertiary。危险操作始终有明确文字与系统 role。没有实际动作时不显示按钮。

`AppSheetStyle` 统一 medium/large detent、可见拖动条、22 圆角、系统 NavigationStack；大字体使用 large。编辑器通过 `appSheet(expanded: true)` 默认展开 large，避免键盘挤压多项输入。取消在 leading cancellationAction，完成/保存在 confirmationAction。内容允许滚动和完整换行。详细信息以标题与分组呈现，不拼成长表格。

## 动画与 Haptic

`AppMotion` 统一 0.22 秒 smooth 按压、0.28 秒 snappy 内容更新；Reduce Motion 下按压仅 0.18 秒透明度反馈，内容更新无自定义位移动画。Hero 身份变化淡入淡出，周内容按新周身份替换，避免旧卡片滑向另一门课。系统负责 Tab/Sheet 导航转场，不强制重建 ViewModel。无入场延迟、循环动画、新 Timer、matchedGeometry 或几何监听。

`AppHaptics` 集中复用 UIKit feedback generators。Tab/前后周/调休、星期、颜色、教学周、安排变更使用 selection，回本周 light，学期/课程/作息保存成功使用 success，课程删除成功 warning。失败不发成功反馈。滚动、分钟刷新、自动同步无触觉。不得每个 body 生成新反馈对象。

## Dark Mode 与 Accessibility

深色有独立 accent 值与系统分层表面，不把浅色彩卡原封不动搬到黑底。课程正文 primary；不通过整行降低透明度表现已结束，改为 secondary 标题与文字状态。Increase Contrast 依赖系统 semantic surface/text；色板、tag tint 必须另行实机核验。Reduce Transparency 不影响内容层（内容未使用材质）。

所有独立按钮至少 44pt；极窄冲突卡改用列表。VoiceOver 提供完整课程名、节次、地点和操作提示，装饰线隐藏。Today 日期和状态自适应换行；大字体周表使用无固定行高的列表。详情和空状态说明完整换行。错误与状态必须同时有文字。

## Courses / Editor

课程行：细色标 + 课程名（主）+ 教师/每周次数（次）+ 地点（三级），使用统一表面与间距，不以单行名称加 Chevron 作为最终交付。编辑器按基本信息、多个上课安排、教学周、颜色与备注分组；每个安排独立展开编辑，明确“一门课程、多次上课”的关系。禁止新增颜色前绕过原始数据兼容性检查。

课程行最多预览两条安排，其余显示数量；明确写“上课安排”，不把单双周安排数误称本周次数。颜色与备注渐进展开。安排 Sheet 包含星期、开始/结束节次、继承默认地点的可选输入与教学周。教学周采用随 Dynamic Type 扩展的网格，快捷选择全部/单/双/清除，连续区间放入 DisclosureGroup。

冲突使用独立 Sheet，完整说明课程、重叠节次和周数，“仍然保存”是确认动作而非危险动作。删除才使用 destructive + 确认。课程、安排、作息都使用内存草稿，取消和尝试下拉关闭有放弃更改确认；无修改可直接关闭。列表身份使用 Course ID，安排使用 CourseSchedule ID，不用数组下标。

## 验收与性能

按 Today、网格/大字列表、详情、调休选择、空状态逐页核对对齐、间距、层级、触控、长文本、浅/深色、Reduce Motion。纯 Preview 覆盖中文/英文长名称、长教师与地点、密集/冲突/特殊日以及小屏/大屏。后续 UI 修改必须更新对应 Preview 与验收记录。

不新增 SwiftData Query、EventKit 查询、计时器、AnyView、模糊层或几何测量；Snapshot/Resolver/Layout Engine 继续负责业务与复杂布局。UI 列表 identity 使用既有 occurrence/day ID。Windows 静态检查不等于视觉验收。最终还须 macOS Build/XCTest，Simulator 检查各尺寸，真机确认 haptic、连续操作、滚动帧率和 VoiceOver。
