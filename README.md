# ClassFlow

个人原生 iPhone 大学课表。最低 iOS 17；Swift、SwiftUI、SwiftData、EventKit；核心数据仅保存在本地。

**当前交付范围：Phase 4 课程管理。** Today / Schedule / Courses 三个原生 Tab；支持课程搜索、新建、编辑、删除、多上课安排、教学周选择、10 色、备注和冲突确认。作息时间可在 Courses 配置。编辑过程使用内存 Draft，保存后统一写入 SwiftData。后续页面遵守 [设计系统](DESIGN_SYSTEM.md)。未开发完整 Settings、通知或 Widget。

## 打开与验证

在 Mac 上用 Xcode 打开 `ClassFlow.xcodeproj`，选择共享 Scheme `ClassFlow`。最低 Xcode 15（Swift 5.9）；建议使用支持你 iPhone 系统版本的 Xcode。无 CocoaPods、无外部 Swift Package；`ClassFlowCore` 是仓库内的本地包。

```sh
# 纯 Foundation 业务测试
swift test

# iOS Simulator 编译，不需要开发者签名
xcodebuild -project ClassFlow.xcodeproj -scheme ClassFlow \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build

# 查询本机可用模拟器，使用输出中的真实 UDID
xcrun simctl list devices available
xcodebuild -project ClassFlow.xcodeproj -scheme ClassFlow \
  -destination 'platform=iOS Simulator,id=<本机模拟器UDID>' \
  -derivedDataPath DerivedData -resultBundlePath TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

Xcode 中按 ⌘U 会同时运行核心逻辑测试和 SwiftData/同步集成测试。`swift test` 只运行纯 Swift 核心测试。不要把结构检查通过理解成编译通过。

## Windows 开发与 macOS CI

项目可以在 Windows 上编辑、生成工程并运行结构检查：

```powershell
node scripts/generate-project.mjs
node scripts/verify-structure.mjs
node scripts/verify-design-system.mjs
node scripts/verify-project.mjs
```

Windows 不能验证 Xcode Build、SwiftUI Preview、iOS Simulator、EventKit 或真机权限。仓库包含 [iOS CI](.github/workflows/ios-ci.yml)：推送到 GitHub 后，在 **Actions → iOS CI** 查看运行结果。Workflow 打印环境并发现工程/共享 Scheme，先进行无签名 generic Simulator Build，成功后运行核心测试，动态选择实际存在的 iPhone Simulator 执行 XCTest。Build/Test 失败使 CI 失败；日志和 `.xcresult` 尝试上传为 `ClassFlow-diagnostics`，上传失败另行提示，不掩盖核心结果。

Phase 4.5 已初始化本地 Git（main），未连接远程或上传代码。已完成 Windows 静态检查，**尚未真实编译验证**。当前定义 193 个 XCTest 方法（原 189 + 4 个兼容回归），不是通过数量。状态见 [CI_STATUS](CI_STATUS.md)，审查见 [Phase 4.5](docs/PHASE_4_5.md)，课程功能记录见 [Phase 4](docs/PHASE_4.md)。

由你创建空 GitHub 仓库（可选 Private）或提供已有仓库。先确认 `git remote -v`，没有 origin 时执行以下命令，将 URL 替换为自己的地址；已有 origin 不覆盖，不使用 force push：

```powershell
git remote add origin "<你的 GitHub 仓库 URL>"
git push -u origin main
```

首次 push 会触发 Actions；之后也可在默认分支的 **Actions → iOS CI → Run workflow** 手动运行。认证由你在本机完成。此 CI 不安装真机，不要求 Apple Developer 证书。Build/Test 的 Executed/Passed/Failed/Skipped 只根据实际日志或 xcresult 记录。

## 个人 iPhone 安装

1. 将整个目录复制到 Mac，打开工程。
2. 在 Xcode 的 Signing & Capabilities 中为 ClassFlow 选择自己的 Team，将 Bundle Identifier 改成自己的唯一标识。
3. 连接并信任 iPhone；在设备要求时开启 Developer Mode，选择该设备后运行。
4. 首次在 Today 创建学期，再进入 Courses 配置学校作息、添加课程及上课安排。保存后 Today 和周课表重新读取有效课表。

设备运行与签名按 [Apple 的真机运行流程](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)操作。个人签名的有效期和可用能力取决于开发者账户；当前工程未绑定任何账户或证书。

## 目录

```text
ClassFlow.xcodeproj/      iOS App、测试 Target、共享 Scheme
Package.swift            本地 ClassFlowCore 包，无外部依赖
ClassFlow/
  App/                   容器初始化、前台/日历变更同步入口
  Models/                五个 SwiftData 模型
  DesignSystem/          全局 Tokens、按钮/标签/空状态/Sheet、Motion、Haptic
  Core/
    Utilities/           LocalDay、Weekday、ActiveWeeks
    Schedule/            教学周、值类型输入、统一 ScheduleResolver
    Today/               当前/下一节、课程状态和倒计时快照
    Week/                周快照、周导航、布局与冲突分栏算法
    Calendar/            日历事件快照、保守解析器
    Courses/             编辑草稿、校验、周数格式化、循环课程冲突检测
  Services/
    Persistence/         Schema V1、持久化容器、学期/特殊规则写入
    Schedule/            SwiftData → 统一解析器适配
    Today/               TodayViewModel 与分钟级刷新
    Week/                目标周加载、快照生成与分钟级时间线刷新
    Calendar/            EventKit、来源选择存储、幂等同步
    Courses/             列表加载、原子保存/删除、作息配置写入
  Views/Today/           Today 页面、状态卡、课程卡和 Preview 数据
  Views/Schedule/        周导航、日期头、网格、课程详情和 Preview 数据
  Views/Courses/         课程列表、详情、课程/安排/教学周/作息编辑、Preview
  Resources/             Info.plist、日历权限说明
Tests/
  CoreTests/             纯逻辑 XCTest，可用 swift test 运行
  IntegrationTests/      SwiftData 和 Calendar 同步 XCTest，需要 iOS SDK
docs/                    架构决策、验收记录
scripts/                 工程再生成、跨平台结构检查
```

细节见 [架构说明](docs/ARCHITECTURE.md)。Today 与 Schedule 都复用 `ScheduleService` / `ScheduleResolver`；后续消费者也必须沿用这个入口。

## 工程维护

工程文件已提交到工作目录，打开或构建不需要 Node。增加/移除 Swift 文件后，可直接在 Xcode 中维护 Target Membership；也可以使用：

```sh
node scripts/generate-project.mjs
node scripts/verify-structure.mjs
```

生成器会重写工程与共享 Scheme。若以后设置了 Team、Bundle Identifier 或其他构建配置，需先同步修改生成器中的配置，避免再生成时覆盖个人设置。
