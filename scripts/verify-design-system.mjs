// Source-level design contract checks; does not render SwiftUI or compile Swift.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
function files(dir) {
  return fs.readdirSync(path.join(root, dir), {withFileTypes:true}).flatMap(e =>
    e.isDirectory() ? files(`${dir}/${e.name}`) : [`${dir}/${e.name}`]);
}
const views = [...files('ClassFlow/Views'), ...files('ClassFlow/Components')].filter(p=>p.endsWith('.swift'));
for (const p of views) {
  const s=read(p);
  assert(!/\.padding\((?:\.[a-z]+,\s*)?\d/.test(s), `Unscoped padding: ${p}`);
  assert(!/cornerRadius:\s*\d/.test(s), `Unscoped radius: ${p}`);
  assert(!/\.font\(\./.test(s), `Unscoped font: ${p}`);
  assert(!/\bAnyView\b|GeometryReader|\.blur\(/.test(s), `Expensive UI shortcut: ${p}`);
  assert(!/\.frame\(width:[^\n]*minHeight:/.test(s), `Invalid frame overload: ${p}`);
  const code = s.replace(/"(?:\\.|[^"\\])*"|\/\/[^\n]*|\/\*[^]*?\*\//g, '');
  assert(!/\.environment\s*\(\s*\\\.(?:accessibilityReduceMotion|colorSchemeContrast)\b/.test(code),
    `Cannot write read-only system accessibility environment values: ${p}`);
}
const colors=read('ClassFlow/DesignSystem/AppColors.swift');
const pairs=[...colors.matchAll(/pair = \(0x([A-F0-9]+), 0x([A-F0-9]+)\)/g)];
assert.equal(pairs.length,10);
const rgb = hex => [16,8,0].map(shift=>((parseInt(hex,16)>>shift)&255)/255);
const luminance = c => c.map(v=>v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4)
  .reduce((sum,v,i)=>sum+v*[0.2126,0.7152,0.0722][i],0);
const ratio = (a,b) => (Math.max(luminance(a),luminance(b))+0.05)/(Math.min(luminance(a),luminance(b))+0.05);
let minimum=Infinity;
for (const [,light,dark] of pairs) {
  for (const [accent,base] of [[rgb(light),rgb('FFFFFF')],[rgb(dark),rgb('1C1C1E')]]) {
    const tinted=accent.map((c,i)=>c*0.12+base[i]*0.88);
    const contrast=ratio(accent,tinted);
    minimum=Math.min(minimum,contrast);
    assert(contrast>=4.5, `Palette contrast below 4.5: ${light}/${dark}: ${contrast}`);
  }
}
const motion=read('ClassFlow/DesignSystem/AppMotion.swift');
assert(motion.includes('accessibilityReduceMotion'));
assert(read('ClassFlow/Views/Schedule/WeekSchedulePageView.swift').includes('dynamicType.isAccessibilitySize'));
assert(read('ClassFlow/Views/Schedule/WeekAccessibleAgenda.swift').includes('fixedSize(horizontal: false, vertical: true)'));
console.log(`PASS: ${views.length} UI files use scoped padding, typography and radii; no blur/AnyView/GeometryReader.`);
console.log(`PASS: 10 adaptive accents; minimum calculated contrast on 12% tinted reference surfaces ${minimum.toFixed(2)}:1.`);
console.log('PASS: Reduce Motion and accessible week presentation present. Visual/device verification remains pending.');
