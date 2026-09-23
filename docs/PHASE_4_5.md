# Phase 4.5 — Repository / macOS CI / Compile Validation Gate

2026-09-23。仅验证准备与兼容修复；未新增业务功能或 UI，未改变 Schema、关系或 ScheduleResolver。

## 本地仓库与 hygiene

- 初始化本地 `main`；仅本仓库配置用户提供的提交作者。未登录 GitHub、创建远程仓库、添加 remote 或推送。
- 首次沙箱账户创建空 Git 元数据触发跨账户 ownership 检查；确认无提交、无暂存、无远程后，以用户账户重新初始化空元数据。未设置全局 safe.directory 例外。
- `.gitignore` 忽略 DerivedData、.build、xcuserdata、xcuserstate、xcresult、构建产物、临时文件、IDE 缓存和本地环境文件；源码、Tests、共享 Xcode 工程/Scheme、工作流、脚本与文档均可提交。
- `.gitattributes` 统一源码、脚本、YAML、工程文本为 LF，减少跨平台换行噪声。
- 正式 Swift、Tests、工程、脚本和 YAML 未检出本机绝对 Windows 路径、用户名或电脑名。Git 提交身份只保存在不提交的 `.git/config` 和提交记录中。

## 工程与静态审查

新增 `scripts/verify-project.mjs`，解析真实 OpenStep 工程对象，而不只搜索文件名。检查对象引用、Source Build Phase、App/Test 隔离、本地 Package 链接、共享 Scheme 和重复顶层类型。

| 所属 Target | Swift 源文件 |
| --- | ---: |
| ClassFlow App | 52 |
| ClassFlowTests | 14（其中包含测试 fixture 源文件） |
| ClassFlowCore 本地 Package | 14 |

未发现漏加、重复加入或错误 Target Membership。Core 不重复编译进 App Sources，通过 Package product 分别供 App/Test 链接。共享 Scheme 位于 `ClassFlow.xcodeproj/xcshareddata/xcschemes/ClassFlow.xcscheme`，测试项未跳过；Scheme 与 Info.plist 均通过 Windows XML 解析。

最低 iOS 17 和 Swift 5 language mode 保持不变；未检出无保护的 iOS 18/26 专属 API。审查覆盖 @Model/关系、@Environment/@State/@Binding、NavigationStack、Sheet、confirmationDialog、Preview、Task、MainActor、Equatable/Sendable 值类型、EventKit。当前没有 @Query/@Observable 或 UserNotifications 占位实现。已有 API 包括 iOS 17 的 SwiftData、onChange 新闭包和动画，以及 iOS 16/17 可用的系统 Sheet/Picker。此结论是源码审查，SDK 可用性、SwiftUI 泛型和宏展开仍必须由真实 Build 验证。

参考官方依据：[EventKit iOS 17 权限迁移](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels)、[SwiftUI onChange](https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:))、[WWDC23 SwiftUI Animation](https://developer.apple.com/videos/play/wwdc2023/10156/)。

## CourseRepository、颜色和作息

创建/编辑均在 MainActor 的独立 ModelContext 中，关闭 autosave，先验证原始身份和冲突；编辑更新原 Course，安排按 UUID upsert，移除仅删对应子模型。失败 rollback，课程删除复用原 cascade。已有集成测试覆盖重复 ID、过期编辑、半写入失败与级联；尚未执行。

发现并修复：未知颜色读取不会写数据库，但 Phase 4 草稿只携带 fallback 枚举，保存其他字段可能将原始键覆盖蓝色。现在 CourseDefinition/CourseDraft 携带原始 `colorKey`，`CourseColor.resolve` 只决定显示；Repository 保存原始键。只有显式选色才替换键。原 10 个键含历史 6 键继续原映射；未发现其他真实历史 alias，不猜测添加。SwiftData 的 `colorRawValue` 字段保持原样，无迁移。

新增 4 个 XCTest 方法：合法/未知颜色键映射、主动选色、读取及编辑备注保留未知键、直接调用底层 SemesterRepository 不能删除被引用节次。保留原 189 个，共 **定义 193 个**；未执行。TimeSlot 删除保护同时存在于 CourseRepository 和 SemesterRepository，覆盖开始到结束的所有中间节次。

Preview 代码受 DEBUG 条件控制，使用值类型 fixture；静态检查确认无真实 ModelContainer/Context、EventKit/权限调用，生产路径无样例自动插入。Preview 虽无需数据服务，仍须 macOS 渲染验证。

## CI 最终流程

1. `macos-latest` checkout；不持久化凭据。
2. 打印并保存 sw_vers、Xcode、Swift、runtime 和 available simulator 信息。
3. 查找顶层 workspace/project；多容器歧义直接报错。`xcodebuild -list -json` 输出 Scheme 列表；优先 ClassFlow，不在多 Scheme 中静默猜测。
4. Node 结构/设计/Target 检查、Python 原验证器、plutil。
5. Debug generic iOS Simulator `clean build`，关闭 code signing，保存 Build.xcresult 与 build.log。
6. Build 成功后运行纯 Core XCTest，再从实际 available iOS >=17 的 iPhone 中选择模拟器、启动并运行 `xcodebuild test`，保存 Tests.xcresult 与 xctest.log。
7. 无论成功失败，尝试上传 ClassFlow-diagnostics；包含环境日志、Scheme JSON、Build/Test 结果和日志。
8. 最后按每步真实 outcome 生成 Actions Summary。只有 artifact 传输允许 best-effort；核心 Build/Test 无 continue-on-error，管道启用 pipefail，不被 tee 掩盖。上传失败单独警告，不改写 Build/Test 结果。

现有 Node/Python 检查器已将“任何 continue-on-error 一律禁止”细化为“只允许唯一的 artifact 上传步骤”，没有放宽 Build/Test 检查。[官方 checkout releases](https://github.com/actions/checkout/releases) 与 [upload-artifact](https://github.com/actions/upload-artifact) 已核对所用 v7 系列。

## 实际执行与未执行

Windows 已执行：project generator、verify-structure、verify-design-system、verify-project，XML 解析、9 个 workflow run block 的 Git Bash `-n` 语法检查、Git ignore/remote/hygiene 检查。无重复顶层类型，核心文件未被忽略。Bash 仅解析语法，没有运行 macOS 命令。

Python launcher 存在，但没有安装 Python runtime，原 `verify_structure.py` 在 Windows 未能执行；等效的工程对象/Target 核对已由新增 Node 验证器执行，CI 将运行两者。当前没有 Swift 或 Xcode；macOS Build、XCTest、Simulator、真机均 **Not run**。没有 GitHub remote，不能触发真实 CI。实时状态见根目录 `CI_STATUS.md`。

下一步由用户创建或提供 GitHub 仓库，连接并 push。无需 Apple 证书即可跑 Simulator CI。观察 Actions → iOS CI；失败时提供失败步骤日志或下载 ClassFlow-diagnostics。不要把本地结构验证或 193 个定义方法视作 Gate 已真实通过。
