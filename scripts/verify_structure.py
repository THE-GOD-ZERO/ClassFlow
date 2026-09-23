"""Portable structural checks, NOT a Swift compiler or replacement for Xcode/XCTest."""
import json
import pathlib
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]


def parse_openstep(text):
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', text)
    offset = 0

    def take(expected=None):
        nonlocal offset
        token = tokens[offset]
        offset += 1
        if expected is not None:
            assert token == expected, (token, expected)
        return token

    def value():
        token = take()
        if token == "{":
            result = {}
            while tokens[offset] != "}":
                key = value()
                take("=")
                assert key not in result, f"Duplicate project key: {key}"
                result[key] = value()
                take(";")
            take("}")
            return result
        if token == "(":
            result = []
            while tokens[offset] != ")":
                result.append(value())
                if tokens[offset] == ",":
                    take(",")
                else:
                    break
            take(")")
            return result
        return json.loads(token) if token.startswith('"') else token

    result = value()
    assert offset == len(tokens)
    return result


project = parse_openstep((ROOT / "ClassFlow.xcodeproj/project.pbxproj").read_text(encoding="utf-8"))
objects = project["objects"]
assert project["rootObject"] in objects
reference_keys = {"fileRef", "productRef", "containerPortal", "remoteGlobalIDString", "target", "targetProxy",
                  "buildConfigurationList", "productReference", "package", "mainGroup", "productRefGroup"}
reference_arrays = {"children", "files", "buildPhases", "dependencies", "packageProductDependencies",
                    "buildConfigurations", "packageReferences", "targets"}
for identifier, obj in objects.items():
    assert re.fullmatch(r"[A-F0-9]{24}", identifier)
    for key in reference_keys & obj.keys():
        assert obj[key] in objects, (identifier, key, obj[key])
    for key in reference_arrays & obj.keys():
        assert len(obj[key]) == len(set(obj[key])), (identifier, key, "duplicate reference")
        assert all(item in objects for item in obj[key]), (identifier, key)
    if obj["isa"] == "PBXFileReference" and obj.get("sourceTree") == "SOURCE_ROOT":
        assert (ROOT / obj["path"]).is_file(), obj["path"]

targets = {obj["name"]: obj for obj in objects.values() if obj["isa"] == "PBXNativeTarget"}
assert set(targets) == {"ClassFlow", "ClassFlowTests"}
for name, folder in [("ClassFlow", "ClassFlow"), ("ClassFlowTests", "Tests")]:
    phases = [objects[item] for item in targets[name]["buildPhases"]]
    sources = next(p for p in phases if p["isa"] == "PBXSourcesBuildPhase")
    included = {objects[objects[item]["fileRef"]]["path"] for item in sources["files"]}
    expected = {p.relative_to(ROOT).as_posix() for p in (ROOT / folder).rglob("*.swift")
                if "Core" not in p.relative_to(ROOT).parts or folder == "Tests"}
    assert included == expected, (name, included ^ expected)
    assert len(targets[name]["packageProductDependencies"]) == 1

with (ROOT / "ClassFlow/Resources/Info.plist").open("rb") as handle:
    info = plistlib.load(handle)
assert "节假日" in info["NSCalendarsFullAccessUsageDescription"]
assert "UIBackgroundModes" not in info
scheme = ET.parse(ROOT / "ClassFlow.xcodeproj/xcshareddata/xcschemes/ClassFlow.xcscheme")
for reference in scheme.findall(".//BuildableReference"):
    assert reference.attrib["BlueprintIdentifier"] in objects
assert len(scheme.findall(".//TestableReference")) == 1

workflow_path = ROOT / ".github/workflows/ios-ci.yml"
assert workflow_path.is_file()
workflow = workflow_path.read_text(encoding="utf-8")
for required in ["runs-on: macos-latest", "xcodebuild -version", "swift --version",
                 "xcrun simctl list devices available", "-list -json",
                 "generic/platform=iOS Simulator", "CODE_SIGNING_ALLOWED=NO",
                 "clean build", "-resultBundlePath", "test"]:
    assert required in workflow, f"Missing CI requirement: {required}"
best_effort_steps = [step for step in re.split(r"(?=      - name:)", workflow) if "continue-on-error:" in step]
assert len(best_effort_steps) == 1
assert "id: artifacts" in best_effort_steps[0] and "uses: actions/upload-artifact@" in best_effort_steps[0]
assert not re.search(r"iPhone\s+(?:1[5-9]|2[0-9])", workflow), "CI must select a simulator dynamically"
assert not re.search(r"[A-Za-z]:[\\/]", workflow), "CI contains a Windows absolute path"

swift_files = list((ROOT / "ClassFlow").rglob("*.swift")) + list((ROOT / "Tests").rglob("*.swift"))
for file in swift_files:
    source = file.read_text(encoding="utf-8")
    # Delimiter balance only. Mac checks must still compile macro expansions and type-check SDK APIs.
    stripped = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/', "", source, flags=re.S)
    stack = []
    pairs = {"}": "{", "]": "[", ")": "("}
    for char in stripped:
        if char in "{[(":
            stack.append(char)
        elif char in "}])":
            assert stack and stack.pop() == pairs[char], (file, "unbalanced delimiter")
    assert not stack, (file, stack)
    assert not re.search(r"\b(?:fatalError|try!|as!)", stripped), file
    if "Views" in file.parts:
        # Check executable source, not comments describing Preview isolation or UI copy.
        assert "EventKit" not in stripped and "ScheduleResolver(" not in stripped, file
    if "Core" in file.parts:
        assert not re.search(r"import (SwiftUI|SwiftData|EventKit)", source), file

tests = sum(len(re.findall(r"func test\w+\(", p.read_text(encoding="utf-8")))
            for p in (ROOT / "Tests").rglob("*.swift"))
today_view = (ROOT / "ClassFlow/Views/Today/TodayView.swift").read_text(encoding="utf-8")
today_model = (ROOT / "ClassFlow/Services/Today/TodayViewModel.swift").read_text(encoding="utf-8")
today_core = (ROOT / "ClassFlow/Core/Today/TodaySnapshot.swift").read_text(encoding="utf-8")
assert "ScheduleResolver(" not in today_view
assert "ScheduleService().resolve" in today_model
assert "resolved.needsConfirmation ? []" in today_core
assert len(re.findall(r'#Preview\(', (ROOT / "ClassFlow/Views/Today/TodayPreviewData.swift").read_text(encoding="utf-8"))) >= 8
print(f"PASS: {len(objects)} project objects; all references and target source lists valid.")
print("PASS: Info.plist, shared scheme, Today boundaries, previews and CI configuration checks.")
print(f"Inventory: {len(swift_files)} Swift files; {tests} XCTest methods authored (NOT executed).")
print("Swift compilation, SwiftData runtime checks and XCTest require a Mac with Xcode.")
