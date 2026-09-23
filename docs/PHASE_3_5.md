# Phase 3.5 · Design System 与 UI 审查

2026-09-23，Windows。代码交付完成，视觉验收待 macOS/Simulator/真机。设计规范见根目录 DESIGN_SYSTEM.md；官方来源均链接在规范内。

## 已落实的逐页代码审查

| 页面 | 对齐、密度与层级 | 操作、动画与可访问性 | 仍需设备验证 |
| --- | --- | --- | --- |
| Root / Tab | 原生 TabView，统一 iris 强调色；保留现有两个已实现页面 | 系统切换、不重建 VM，selection 触觉 | iOS 17/26 系统导航外观与触觉频率 |
| Today | 20pt 页面留白、日期层级、一个实色 Hero；后续课程用细色条与分隔线，无卡片墙 | 名称全文换行；状态文字与图标；当前/下一节淡入替换；Reduce Motion 无内容动画 | 小屏、超长名称、最大字体对齐与内容密度 |
| Schedule 网格 | 日期轻 tint；统一 Capsule 特殊标记；细分隔线；课程名→地点→节次；保持同步横滚 | 前后/本周按钮至少44pt；按压反馈；周身份更新；窄冲突卡转列表 | 横纵滚动、快速切周、日期头高度与三重冲突场景 |
| Schedule 可读列表 | 大字体或窄卡使用相同七日快照；日标题与课程完整展开 | 所有名称全文、无固定行高；可点日期确认与课程详情 | VoiceOver 顺序、最大字体、英文长词 |
| 课程详情 | 名称独立主标题、色标、教师与地点分层，教学周另起段落 | List 可滚动、Done 统一位置；无假编辑按钮 | 长地点/教师/备注的换行与 Sheet 升高 |
| 调休选择 | 系统 List、统一解释段落与最小行高 | 保存成功才 selection；取消在 leading；统一 detents/drag indicator | 保存错误 alert 与 Sheet 叠放、连续选择 |
| 空状态 | AppEmptyState 统一符号容器、标题、一句说明、可选主要按钮 | 文本可换行，符号对 VoiceOver 隐藏 | 浅/深色视觉平衡、低亮度阅读 |

## 改动边界

没有修改 Core、ScheduleResolver、SwiftData Schema、模型、关系、持久化字段或现有业务 ViewModel。改动集中在 DesignSystem、App/Views/Components，以及纯 Preview 数据。既有持久化颜色仍为六个键；十色色板的其余四个仅为未来设计储备。调休写入仍走原服务，动画与 Haptic 不参与业务结果计算。

现有工程实际仅有 Today/Schedule 两个 Tab。最终四 Tab 顺序已记录，未新增空 Courses/Settings 页面或本阶段之外的业务。

静态审查修复既有周标题 `frame(width:minHeight:)` 无效参数组合，改用两个合法 frame 修饰符。Today 行中可无限伸展的装饰 Capsule 改为 overlay，避免参与行高计算。

## 验证结果与范围

- `node scripts/generate-project.mjs` 重新生成源码引用。
- `node scripts/verify-structure.mjs`：63 个 Swift 文件，135 个 XCTest 方法，模块边界、引用和分隔符检查通过；测试没有执行。
- `node scripts/verify-design-system.mjs`：12 个 View/Component 文件无裸 padding/radius/font，无 AnyView/GeometryReader/Blur；10 个强调色在白色与 #1C1C1E 的 12% tint 参考底色上最低计算对比度 4.53:1。这只是 sRGB 数值检查，不能替代系统实际材质、辅助对比度和设备验证。
- 保留原 CI Build/Test，额外加入两项 Node 检查。当前目录无 Git remote，未实际运行 CI，尚未真实编译验证。
- 33 个 Preview 声明：原 Today 8、Schedule 19、Design System/边界 6。全部开发值数据，无真实存储写入。

## 发布前视觉门槛

在 320/375/430pt 宽度、Light/Dark、默认/最大字号运行 Preview/Simulator。对长中英文名称、长教师与地点、密集/冲突课程、节假日、待确认调休、无课程/无学期逐页记录截图和问题；特别检查连续点击切周不会延迟。用真机体验 selection/light/success 强度并开启 Reduce Motion、VoiceOver、Increase Contrast、Reduce Transparency。使用 Instruments 检查滚动和切周主线程开销，未测得帧率之前不声称“60/120fps 已达标”。

下一阶段可依据 DESIGN_SYSTEM.md 开发课程管理，仍需先检查现有项目。此阶段停止，不实现第四阶段功能。
