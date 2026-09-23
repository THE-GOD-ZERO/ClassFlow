// Portable structural checks. This is not a Swift compiler or a replacement for Xcode/XCTest.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
const walk = relative => fs.readdirSync(path.join(root, relative), { withFileTypes: true }).flatMap(entry => {
  const child = `${relative}/${entry.name}`;
  return entry.isDirectory() ? walk(child) : [child];
});
const swiftFiles = [...walk('ClassFlow'), ...walk('Tests')].filter(file => file.endsWith('.swift'));
const project = read('ClassFlow.xcodeproj/project.pbxproj');

for (const file of swiftFiles) {
  const belongsToPackage = file.startsWith('ClassFlow/Core/');
  if (!belongsToPackage && !project.includes(`path = ${JSON.stringify(file)}`)) {
    throw new Error(`Project omits ${file}`);
  }
  const source = read(file);
  const stripped = source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '')
    .replace(/"(?:\\.|[^"\\])*"/g, '""');
  const stack = [];
  const pairs = { '}': '{', ']': '[', ')': '(' };
  for (const character of stripped) {
    if ('{[('.includes(character)) stack.push(character);
    if ('}])'.includes(character) && stack.pop() !== pairs[character]) {
      throw new Error(`Unbalanced delimiter in ${file}`);
    }
  }
  if (stack.length) throw new Error(`Unbalanced delimiter in ${file}`);
  if (/\b(?:fatalError|try!|as!)\b/.test(stripped)) throw new Error(`Unsafe forced operation in ${file}`);
  if (file.includes('/Views/') && (/import EventKit/.test(source) || /ScheduleResolver\s*\(/.test(source))) {
    throw new Error(`View crosses service boundary: ${file}`);
  }
  if (file.includes('/Core/') && /import (?:SwiftUI|SwiftData|EventKit)/.test(source)) {
    throw new Error(`Core has an Apple UI/data dependency: ${file}`);
  }
}

const workflow = read('.github/workflows/ios-ci.yml');
for (const required of ['runs-on: macos-latest', 'xcodebuild -version', 'swift --version',
  'xcrun simctl list devices available', 'generic/platform=iOS Simulator',
  'CODE_SIGNING_ALLOWED=NO', 'clean build', '-resultBundlePath', 'test']) {
  if (!workflow.includes(required)) throw new Error(`CI omits ${required}`);
}
const bestEffortSteps = workflow.split(/(?=      - name:)/).filter(step => step.includes('continue-on-error:'));
if (bestEffortSteps.length !== 1 || !bestEffortSteps[0].includes('id: artifacts') ||
    !bestEffortSteps[0].includes('uses: actions/upload-artifact@')) throw new Error('Only artifact upload may be best-effort');
if (/iPhone\s+(?:1[5-9]|2[0-9])/.test(workflow)) throw new Error('CI hard-codes a simulator model');
if ((read('ClassFlow/Views/Schedule/WeekSchedulePreviewData.swift').match(/#Preview\(/g) ?? []).length < 13) {
  throw new Error('Schedule preview coverage is incomplete');
}
const scheduleView = read('ClassFlow/Views/Schedule/WeekScheduleView.swift')
  + read('ClassFlow/Views/Schedule/WeekSchedulePageView.swift');
if (/ScheduleResolver\s*\(/.test(scheduleView) || /Calendar\.component/.test(scheduleView)) {
  throw new Error('Schedule View contains resolver/date business logic');
}
if (!read('ClassFlow/Services/Week/WeekScheduleService.swift').includes('ScheduleService()')) {
  throw new Error('WeekScheduleService does not use the shared ScheduleService');
}
const tests = walk('Tests').filter(file => file.endsWith('.swift'))
  .reduce((sum, file) => sum + (read(file).match(/func test\w+\s*\(/g) ?? []).length, 0);
console.log(`PASS: ${swiftFiles.length} Swift files are referenced with balanced delimiters and clean boundaries.`);
console.log('PASS: Schedule resolver boundary, previews, shared project, and macOS CI markers are present.');
console.log(`Inventory: ${tests} XCTest methods authored (NOT executed).`);
console.log('Swift compilation, SwiftData runtime checks, SwiftUI previews, and XCTest require macOS with Xcode.');
