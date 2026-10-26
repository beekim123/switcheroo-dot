import fs from 'node:fs';import path from 'node:path';import {at,inside,hash} from '../lib/paths.mjs';
const verify=process.argv.includes('--verify'),entries=[];
function add(id,source,dest){const bytes=fs.readFileSync(source);if(bytes.length>=2_000_000)throw Error('Oversized resource '+id);entries.push({id,path:dest,hash:hash(bytes),source});}
for(const kind of ['art','audio']){
 const base=at(`resources/${kind}/export`),manifest=JSON.parse(fs.readFileSync(path.join(base,'manifest.json'),'utf8'));
 add(`manifest.${kind}`,path.join(base,'manifest.json'),`resources/${kind}/manifest.json`);
 for(const item of manifest.assets)add(item.id,inside(base,item.file),`resources/${kind}/${item.file}`);
}
const reg=JSON.parse(fs.readFileSync(at('content/registry.json'),'utf8'));add('content.registry',at('content/registry.json'),'data/registry.json');
for(const rel of reg.files)add(`content.${rel}`,inside(at('content'),rel),`data/${rel}`);
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(d=>d.isDirectory()?walk(path.join(dir,d.name)):[path.join(dir,d.name)]);}
const fonts=at('third_party/fonts');for(const source of walk(fonts)){const rel=path.relative(fonts,source);add(`font.${rel}`,source,`resources/fonts/${rel}`);}
const expected={format:'resource-pack/1',files:entries.map(({source,...e})=>e).sort((a,b)=>a.path.localeCompare(b.path))};
const pack=at('godot/resource-pack.json'),json=JSON.stringify(expected,null,2)+'\n';
if(verify){if(fs.readFileSync(pack,'utf8')!==json)throw Error('Resource pack manifest drift');for(const e of entries)if(!fs.readFileSync(inside(at('godot'),e.path)).equals(fs.readFileSync(e.source)))throw Error('Synchronized copy drift: '+e.path);}
else{let old={files:[]};if(fs.existsSync(pack))old=JSON.parse(fs.readFileSync(pack,'utf8'));const active=new Set(entries.map(e=>e.path));for(const e of old.files)if(!active.has(e.path)){if(!/^(resources|data)\//.test(e.path))throw Error('Refusing unmanaged deletion');fs.rmSync(inside(at('godot'),e.path),{force:true});}for(const e of entries){const dest=inside(at('godot'),e.path);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(e.source,dest);}fs.writeFileSync(pack,json);}
// Import sidecars are engine metadata, but the source pipeline owns quality settings.
// Preserve generated UIDs/dependency paths; never edit synchronized binary bytes.
for(const e of entries){
 const settings=e.path.endsWith('.wav')?{'compress/mode':'0','edit/normalize':'false','edit/trim':'false'}:e.path.endsWith('.ttf')?{'antialiasing':'0','hinting':'0','subpixel_positioning':'0','oversampling':'1.0','allow_system_fallback':'false'}:null;
 if(!settings)continue;const sidecar=inside(at('godot'),e.path)+'.import';
 if(!fs.existsSync(sidecar))continue; // Fresh import uses identical project defaults.
 let source=fs.readFileSync(sidecar,'utf8');
 for(const [key,value]of Object.entries(settings)){
  const escaped=key.replace(/[.*+?^${}()|[\\]\\]/g,'\\$&');
  const pattern=new RegExp('^'+escaped+'=.*$','m');
  const line=key+'='+value;
  if(verify){if(!source.split('\n').includes(line))throw Error('Import quality setting drift: '+e.path+' '+key);}
  else source=pattern.test(source)?source.replace(pattern,line):source+'\n'+line+'\n';
 }
 if(!verify)fs.writeFileSync(sidecar,source);
}
console.log(`sync${verify?':verify':''}: ${entries.length} managed files PASS`);
