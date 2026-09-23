# ClassFlow CI Status

Last local Windows structural validation: **2026-09-23 — Passed** (project generator, Node structure/design/project verifiers, Python structure verifier and Git whitespace check).

| Gate | Status |
| --- | --- |
| CI preflight / structure | Passed (run #3) |
| macOS build | Failed (run #3; writes to read-only Preview environment values) |
| Core tests | Not run |
| XCTest | Not run |
| Simulator | Not run |
| Real device | Not run |

193 XCTest methods defined (189 retained + 4 regression methods); execution counts unavailable.
Remote: `https://github.com/THE-GOD-ZERO/ClassFlow.git` (Public, confirmed by owner).
First push triggered [iOS CI #1](https://github.com/THE-GOD-ZERO/ClassFlow/actions/runs/35875143075) for `fae3228`.
The pre-build Python architecture check failed because it matched `EventKit` in a Preview isolation comment. Build, core tests and Simulator tests did not execute.
Runner: macOS 26.6.2, Xcode 26.6 (17F113), Apple Swift 6.3.3. No Simulator was selected before the failure.
Fix committed in `57e76c4`: inspect code with comments/strings removed; architecture assertions and all XCTest methods retained.

Previous: [iOS CI #2](https://github.com/THE-GOD-ZERO/ClassFlow/actions/runs/35875755235), SHA `0e25f38ad7ae1d3981870fe1c4e04690b501cb03`. Preflight passed; generic Simulator build failed on duplicate `WeekSchedulePreviewData.swift` filenames. Fixed in `c1f18d5` by renaming only the View fixture and regenerating references, with a per-module filename guard.

Latest inspected: [iOS CI #3](https://github.com/THE-GOD-ZERO/ClassFlow/actions/runs/35876514737), SHA `c1f18d5822b1df357ab93e80d9395fc66975c938`, matched latest remote main when inspected. Full job log retrieved (1,449 lines). Preflight passed and duplicate filename errors are gone. Generic build failed first at `CoursesPreviewData.swift:87`: `.environment` requires a writable key path, but `accessibilityReduceMotion` and `colorSchemeContrast` are read-only. The same misuse occurs in `WeekSchedulePreviews.swift`; `.increased` inference errors are consequential. Xcode also warned that `previewDevice` is ignored inside `#Preview`.
Core tests, Simulator selection and XCTest were not reached; Executed/Passed/Failed/Skipped test counts are unavailable (workflow-step skips are not skipped XCTest cases).
Pending revalidation: accessibility Preview scenes now inherit system settings instead of attempting invalid writes; the small-screen Preview uses `fixedLayout` traits. Added a source guard that reproduced the original error before repair; all Windows structural checks pass afterwards. Production accessibility behavior, 193 XCTest methods, iOS 17 target, Schema and Resolver are unchanged. Agent Git authentication remains unavailable; the owner must push the local repair commit to trigger its first macOS validation.
Windows structural checks are not Swift compilation or runtime validation.
