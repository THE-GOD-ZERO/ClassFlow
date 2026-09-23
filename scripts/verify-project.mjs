// Parse the actual generated OpenStep project. This is NOT a Swift compiler.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const walk = p => fs.readdirSync(path.join(root,p),{withFileTypes:true}).flatMap(e=>
  e.isDirectory()?walk(`${p}/${e.name}`):[`${p}/${e.name}`]);
const tokens = read('ClassFlow.xcodeproj/project.pbxproj')
  .match(/"(?:\\.|[^"\\])*"|\/\*[^]*?\*\/|\/\/[^\n]*|[{}()=;,]|[^\s{}()=;,]+/g)
  .filter(t=>!t.startsWith('//')&&!t.startsWith('/*'));
let cursor=0;
function take(expected) { const token=tokens[cursor++]; if(expected)assert.equal(token,expected); return token; }
function value() {
  const token=take();
  if(token==='{') {
    const object={};
    while(tokens[cursor]!=='}') { const key=value();take('=');assert(!Object.hasOwn(object,key));object[key]=value();take(';'); }
    take('}');return object;
  }
  if(token==='(') {
    const array=[];
    while(tokens[cursor]!==')') { array.push(value());if(tokens[cursor]===',')take(',');else break; }
    take(')');return array;
  }
  assert(token!==undefined,'Unexpected end of project');
  return token.startsWith('"')?JSON.parse(token):token;
}
const project=value();assert.equal(cursor,tokens.length);
const objects=project.objects;assert(objects[project.rootObject]);
const single=['fileRef','productRef','containerPortal','remoteGlobalIDString','target','targetProxy','buildConfigurationList','productReference','package','mainGroup','productRefGroup'];
const multiple=['children','files','buildPhases','dependencies','packageProductDependencies','buildConfigurations','packageReferences','targets'];
for(const [id,object] of Object.entries(objects)) {
  assert(/^[A-F0-9]{24}$/.test(id));
  for(const key of single)if(object[key])assert(objects[object[key]],`${id}: missing ${key}`);
  for(const key of multiple)if(object[key]) {
    assert.equal(new Set(object[key]).size,object[key].length,`Duplicate ${key}`);
    for(const ref of object[key])assert(objects[ref],`Missing ${ref}`);
  }
  if(object.isa==='PBXFileReference'&&object.sourceTree==='SOURCE_ROOT')assert(fs.existsSync(path.join(root,object.path)),object.path);
  if(object.isa==='XCBuildConfiguration'&&object.buildSettings.IPHONEOS_DEPLOYMENT_TARGET)assert.equal(object.buildSettings.IPHONEOS_DEPLOYMENT_TARGET,'17.0');
}
const targets=Object.entries(objects).filter(([,o])=>o.isa==='PBXNativeTarget');
assert.deepEqual(targets.map(([,o])=>o.name).sort(),['ClassFlow','ClassFlowTests']);
function assertUniqueSwiftFilenames(files, module) {
  const filenames = new Map();
  for (const file of files) {
    const name = path.basename(file).toLowerCase();
    assert(!filenames.has(name), `${module}: duplicate Swift filename: ${filenames.get(name)} and ${file}`);
    filenames.set(name, file);
  }
}
for(const [,target] of targets) {
  const phase=target.buildPhases.map(id=>objects[id]).find(o=>o.isa==='PBXSourcesBuildPhase');
  const actual=phase.files.map(id=>objects[objects[id].fileRef].path).sort();
  const expected=(target.name==='ClassFlow'?walk('ClassFlow').filter(p=>!p.startsWith('ClassFlow/Core/')):walk('Tests')).filter(p=>p.endsWith('.swift')).sort();
  assert.deepEqual(actual,expected,`${target.name} source membership mismatch`);
  assertUniqueSwiftFilenames(actual, target.name);
  assert.equal(target.packageProductDependencies.length,1);
  assert.equal(objects[target.packageProductDependencies[0]].productName,'ClassFlowCore');
  console.log(`PASS: ${target.name}: ${actual.length} Swift source files in the correct target.`);
}
assert(read('Package.swift').includes('path: "ClassFlow/Core"'));
assertUniqueSwiftFilenames(walk('ClassFlow/Core').filter(p=>p.endsWith('.swift')), 'ClassFlowCore');
assert.equal(Object.values(objects).find(o=>o.isa==='XCLocalSwiftPackageReference').relativePath,'.');
const scheme=read('ClassFlow.xcodeproj/xcshareddata/xcschemes/ClassFlow.xcscheme');
for(const [,id] of scheme.matchAll(/BlueprintIdentifier="([A-F0-9]+)"/g))assert.equal(objects[id]?.isa,'PBXNativeTarget');
assert(scheme.includes('TestableReference skipped="NO"'));
assert(scheme.includes('BlueprintName="ClassFlowTests"'));
const sources=[...walk('ClassFlow'),...walk('Tests')].filter(p=>p.endsWith('.swift'));
const names=new Set();
for(const p of sources) {
  const s=read(p);
  for(const [,name] of s.matchAll(/^(?:(?:public|private|final)\s+)*(?:struct|class|enum|protocol)\s+(\w+)/gm)) {
    assert(!names.has(name),`Duplicate top-level type ${name}`);names.add(name);
  }
  if(/Preview/.test(p)) {
    assert(s.includes('#if DEBUG'),`Preview not DEBUG gated: ${p}`);
    assert(!/ModelContext|ModelContainer|EKEventStore\s*\(|requestAccess\(|requestAuthorization\(/.test(s.replace(/\/\/[^\n]*/g,'')),`Preview touches live services: ${p}`);
  } else if(!p.startsWith('Tests/')) assert(!/\b(?:TodayPreviewData|WeekSchedulePreviewData|CoursesPreviewData)\b/.test(s),`Production references fixtures: ${p}`);
}
const formal=[...sources,...walk('scripts'),...walk('.github'),...walk('ClassFlow.xcodeproj')];
for(const p of formal) {
  const s=read(p);
  assert(!/(?:^|[\s"'=])[A-Za-z]:[\\/]/m.test(s),`Absolute Windows path: ${p}`);
}
console.log(`PASS: ${walk('ClassFlow/Core').filter(p=>p.endsWith('.swift')).length} Core files owned by local Swift Package, linked into both targets.`);
console.log('PASS: project references, shared scheme, iOS 17 target, duplicate types, Preview isolation and portable paths.');
console.log('NOT checked: Swift type checking, SDK availability, macro expansion, runtime or visual behavior.');
