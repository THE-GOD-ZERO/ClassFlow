# ClassFlow CI Status

Last local Windows structural validation: **2026-09-23 — Passed** (project generator, Node structure/design/project verifiers, Python structure verifier and Git whitespace check).

| Gate | Status |
| --- | --- |
| CI preflight / structure | Passed (run #2) |
| macOS build | Failed (run #2; duplicate Swift filename) |
| XCTest | Not run |
| Simulator | Not run |
| Real device | Not run |

193 XCTest methods defined (189 retained + 4 regression methods); execution counts unavailable.
Remote: `https://github.com/THE-GOD-ZERO/ClassFlow.git` (Public, confirmed by owner).
First push triggered [iOS CI #1](https://github.com/THE-GOD-ZERO/ClassFlow/actions/runs/35875143075) for `fae3228`.
The pre-build Python architecture check failed because it matched `EventKit` in a Preview isolation comment. Build, core tests and Simulator tests did not execute.
Runner: macOS 26.6.2, Xcode 26.6 (17F113), Apple Swift 6.3.3. No Simulator was selected before the failure.
Fix committed in `57e76c4`: inspect code with comments/strings removed; architecture assertions and all XCTest methods retained.

Latest inspected: [iOS CI #2](https://github.com/THE-GOD-ZERO/ClassFlow/actions/runs/35875755235), SHA `0e25f38ad7ae1d3981870fe1c4e04690b501cb03`, matched remote main when inspected. Preflight, Python validation and plist checks passed. Generic Simulator build failed at SwiftDriver: both Services/Week and Views/Schedule supplied `WeekSchedulePreviewData.swift` to the App module. Repeated arm64/x86_64 errors have the same root cause.
Core tests, Simulator selection and XCTest were not reached; Executed/Passed/Failed/Skipped test counts are unavailable (workflow-step skips are not skipped XCTest cases).
Pending revalidation: renamed only the View preview file to `WeekSchedulePreviews.swift`, regenerated the project, updated the preview inventory path, and added a per-module duplicate Swift filename guard. The guard reproduced the failure before the rename; all Windows structural checks passed afterwards. Preview contents, 193 XCTest methods, deployment target, Schema and Resolver are unchanged. The fix still needs a new macOS CI run.
Windows structural checks are not Swift compilation or runtime validation.
