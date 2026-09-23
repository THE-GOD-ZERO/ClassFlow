// Deterministic project generation; Node is needed only when regenerating, never by the app or Xcode build.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const id = name => crypto.createHash('sha256').update(name).digest('hex').slice(0, 24).toUpperCase();
const quote = value => JSON.stringify(value);
const objects = [];
const add = (name, body) => { const key = id(name); objects.push(`\t\t${key} = { ${body} };`); return key; };
const array = values => `(${values.join(', ')})`;
function filesIn(relative) {
  return fs.readdirSync(path.join(root, relative), { withFileTypes: true }).flatMap(entry => {
    const file = `${relative}/${entry.name}`;
    return entry.isDirectory() ? filesIn(file) : [file];
  }).sort();
}
const appFiles = filesIn('ClassFlow').filter(file => file.endsWith('.swift') && !file.startsWith('ClassFlow/Core/'));
const testFiles = filesIn('Tests').filter(file => file.endsWith('.swift'));
const appBuildFiles = [];
const testBuildFiles = [];
function makeGroup(name, files) {
  const children = files.map(file => {
    const ref = add(`file:${file}`, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${quote(file)}; sourceTree = SOURCE_ROOT;`);
    const build = add(`build:${file}`, `isa = PBXBuildFile; fileRef = ${ref};`);
    (name === 'Sources' ? appBuildFiles : testBuildFiles).push(build);
    return ref;
  });
  return add(`group:${name}`, `isa = PBXGroup; name = ${name}; children = ${array(children)}; sourceTree = "<group>";`);
}
const sourceGroup = makeGroup('Sources', appFiles);
const testGroup = makeGroup('Tests', testFiles);
const infoRef = add('info', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = ClassFlow/Resources/Info.plist; sourceTree = SOURCE_ROOT;');
const packageRef = add('packageFile', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Package.swift; sourceTree = SOURCE_ROOT;');
const appProduct = add('appProduct', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = ClassFlow.app; sourceTree = BUILT_PRODUCTS_DIR;');
const testProduct = add('testProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = ClassFlowTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
const products = add('products', `isa = PBXGroup; name = Products; children = ${array([appProduct, testProduct])}; sourceTree = "<group>";`);
const mainGroup = add('mainGroup', `isa = PBXGroup; children = ${array([sourceGroup, testGroup, infoRef, packageRef, products])}; sourceTree = "<group>";`);
const localPackage = add('localPackage', 'isa = XCLocalSwiftPackageReference; relativePath = .;');
const appPackageProduct = add('appPackageProduct', `isa = XCSwiftPackageProductDependency; package = ${localPackage}; productName = ClassFlowCore;`);
const testPackageProduct = add('testPackageProduct', `isa = XCSwiftPackageProductDependency; package = ${localPackage}; productName = ClassFlowCore;`);
const coreAppBuild = add('coreAppBuild', `isa = PBXBuildFile; productRef = ${appPackageProduct};`);
const coreTestBuild = add('coreTestBuild', `isa = PBXBuildFile; productRef = ${testPackageProduct};`);
function phase(name, isa, files) {
  return add(name, `isa = ${isa}; buildActionMask = 2147483647; files = ${array(files)}; runOnlyForDeploymentPostprocessing = 0;`);
}
const appPhases = [phase('appSources', 'PBXSourcesBuildPhase', appBuildFiles),
  phase('appFrameworks', 'PBXFrameworksBuildPhase', [coreAppBuild]), phase('appResources', 'PBXResourcesBuildPhase', [])];
const testPhases = [phase('testSources', 'PBXSourcesBuildPhase', testBuildFiles),
  phase('testFrameworks', 'PBXFrameworksBuildPhase', [coreTestBuild]), phase('testResources', 'PBXResourcesBuildPhase', [])];
const proxy = add('proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${id('appTarget')}; remoteInfo = ClassFlow;`);
const dependency = add('dependency', `isa = PBXTargetDependency; target = ${id('appTarget')}; targetProxy = ${proxy};`);
function configList(name, common, debug = {}, release = {}) {
  const configurations = ['Debug', 'Release'].map(configuration => {
    const settings = { ...common, ...(configuration === 'Debug' ? debug : release) };
    const body = Object.entries(settings).map(([key, value]) => `${key} = ${quote(String(value))};`).join(' ');
    return add(`${name}:${configuration}`, `isa = XCBuildConfiguration; buildSettings = { ${body} }; name = ${configuration};`);
  });
  return add(`${name}:list`, `isa = XCConfigurationList; buildConfigurations = ${array(configurations)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
}
const projectConfigs = configList('projectConfigs', {
  IPHONEOS_DEPLOYMENT_TARGET: '17.0', SDKROOT: 'iphoneos', SWIFT_VERSION: '5.0',
  CLANG_ENABLE_MODULES: 'YES', CLANG_ENABLE_OBJC_ARC: 'YES',
  GCC_C_LANGUAGE_STANDARD: 'gnu17', SWIFT_STRICT_CONCURRENCY: 'complete',
  ENABLE_USER_SCRIPT_SANDBOXING: 'YES'
}, { DEBUG_INFORMATION_FORMAT: 'dwarf', ENABLE_TESTABILITY: 'YES', GCC_OPTIMIZATION_LEVEL: '0',
  SWIFT_OPTIMIZATION_LEVEL: '-Onone', SWIFT_ACTIVE_COMPILATION_CONDITIONS: 'DEBUG $(inherited)', ONLY_ACTIVE_ARCH: 'YES'
}, { DEBUG_INFORMATION_FORMAT: 'dwarf-with-dsym', SWIFT_COMPILATION_MODE: 'wholemodule', SWIFT_OPTIMIZATION_LEVEL: '-O' });
const shared = { CODE_SIGN_STYLE: 'Automatic', CURRENT_PROJECT_VERSION: '1', MARKETING_VERSION: '0.1.0',
  TARGETED_DEVICE_FAMILY: '1', SUPPORTED_PLATFORMS: 'iphoneos iphonesimulator', SUPPORTS_MACCATALYST: 'NO',
  PRODUCT_NAME: '$(TARGET_NAME)' };
const appConfigs = configList('appConfigs', { ...shared,
  PRODUCT_BUNDLE_IDENTIFIER: 'com.classflow.personal', GENERATE_INFOPLIST_FILE: 'NO',
  INFOPLIST_FILE: 'ClassFlow/Resources/Info.plist', LD_RUNPATH_SEARCH_PATHS: '$(inherited) @executable_path/Frameworks',
  ENABLE_PREVIEWS: 'YES'
});
const testConfigs = configList('testConfigs', { ...shared,
  PRODUCT_BUNDLE_IDENTIFIER: 'com.classflow.personal.tests', GENERATE_INFOPLIST_FILE: 'YES',
  BUNDLE_LOADER: '$(TEST_HOST)', TEST_HOST: '$(BUILT_PRODUCTS_DIR)/ClassFlow.app/ClassFlow',
  LD_RUNPATH_SEARCH_PATHS: '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'
});
add('appTarget', `isa = PBXNativeTarget; buildConfigurationList = ${appConfigs}; buildPhases = ${array(appPhases)}; buildRules = (); dependencies = (); name = ClassFlow; packageProductDependencies = ${array([appPackageProduct])}; productName = ClassFlow; productReference = ${appProduct}; productType = "com.apple.product-type.application";`);
add('testTarget', `isa = PBXNativeTarget; buildConfigurationList = ${testConfigs}; buildPhases = ${array(testPhases)}; buildRules = (); dependencies = ${array([dependency])}; name = ClassFlowTests; packageProductDependencies = ${array([testPackageProduct])}; productName = ClassFlowTests; productReference = ${testProduct}; productType = "com.apple.product-type.bundle.unit-test";`);
add('project', `isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = { ${id('appTarget')} = { CreatedOnToolsVersion = 16.0; }; ${id('testTarget')} = { CreatedOnToolsVersion = 16.0; TestTargetID = ${id('appTarget')}; }; }; }; buildConfigurationList = ${projectConfigs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = ("zh-Hans", en, Base); mainGroup = ${mainGroup}; packageReferences = ${array([localPackage])}; productRefGroup = ${products}; projectDirPath = ""; projectRoot = ""; targets = ${array([id('appTarget'), id('testTarget')])};`);
const projectDir = path.join(root, 'ClassFlow.xcodeproj');
fs.mkdirSync(path.join(projectDir, 'xcshareddata/xcschemes'), { recursive: true });
fs.writeFileSync(path.join(projectDir, 'project.pbxproj'), `// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n${objects.join('\n')}\n\t};\n\trootObject = ${id('project')};\n}\n`);
const reference = (target, product, name) => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id(target)}" BuildableName="${product}" BlueprintName="${name}" ReferencedContainer="container:ClassFlow.xcodeproj"/>`;
const appReference = reference('appTarget', 'ClassFlow.app', 'ClassFlow');
const testReference = reference('testTarget', 'ClassFlowTests.xctest', 'ClassFlowTests');
fs.writeFileSync(path.join(projectDir, 'xcshareddata/xcschemes/ClassFlow.xcscheme'), `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${appReference}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">${testReference}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables><TestableReference skipped="NO">${testReference}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${appReference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${appReference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
`);
console.log(`Generated ClassFlow.xcodeproj: ${appFiles.length} app sources, ${testFiles.length} test files; core linked as local Swift package.`);
