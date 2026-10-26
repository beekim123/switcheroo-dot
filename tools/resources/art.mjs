#!/usr/bin/env node
/** Switcheroo's standalone, original code-drawn art pipeline. */
import { readFile, writeFile, readdir, mkdir } from 'node:fs/promises';
import { resolve, join, dirname, relative } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { PixelCanvas, characterFrame } from '../../resources/art/lib/pixel.mjs';
import { encodePNG, decodePNG } from '../../resources/art/lib/png.mjs';

export const ROOT=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const MAX_FILE_BYTES=2_000_000;
const sha256=bytes=>createHash('sha256').update(bytes).digest('hex');
const json=value=>Buffer.from(JSON.stringify(value,null,2)+'\n');
const fail=message=>{throw new Error(message);};
const isRecord=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
async function filesBelow(directory) {
  let entries;
  try { entries=await readdir(directory,{withFileTypes:true}); }
  catch(error){if(error.code==='ENOENT')return [];throw error;}
  const files=[];
  for(const entry of entries.sort((a,b)=>a.name<b.name?-1:a.name>b.name?1:0)) {
    if(entry.isDirectory())files.push(...await filesBelow(join(directory,entry.name)));
    else if(entry.isFile())files.push(join(directory,entry.name));
    else fail(`Art input cannot be a symlink: ${entry.name}`);
  }
  return files;
}
export function validatePalette(palette) {
  if(palette.format!=='palette/1'||!isRecord(palette.colors)||Object.keys(palette.colors).length!==47)fail('Palette must contain exactly 47 named colors');
  const hexes=Object.values(palette.colors);
  if(hexes.some(hex=>!/^#[0-9a-f]{6}$/.test(hex))||new Set(hexes).size!==47)fail('Palette colors must be unique lowercase RGB hex');
  if(!isRecord(palette.chars)||Object.keys(palette.chars).length!==47||new Set(Object.values(palette.chars)).size!==47)fail('Palette needs one character per color');
  for(const [symbol,name] of Object.entries(palette.chars))if(symbol.length!==1||symbol==='.'||!palette.colors[name])fail('Invalid palette character mapping');
  for(const id of ['dream','dark_slot','ghost']) {
    const map=palette.swaps?.[id];
    if(!isRecord(map)||Object.keys(map).length!==47)fail(`Incomplete swap: ${id}`);
    for(const name of Object.keys(palette.colors))if(!palette.colors[map[name]])fail(`Invalid swap target: ${id}.${name}`);
  }
  return palette;
}
export function validateMeta(meta) {
  if(!/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/.test(meta.id))fail('Invalid art id');
  if(!Array.isArray(meta.size)||meta.size.length!==2||meta.size.some(n=>!Number.isInteger(n)||n<1||n>4096))fail(`${meta.id}: invalid frame size`);
  if(!Number.isInteger(meta.frames)||meta.frames<1||meta.frames>256||meta.size[0]*meta.size[1]*meta.frames>16_777_216)fail(`${meta.id}: invalid frame count`);
  if(!Array.isArray(meta.anchor)||meta.anchor.length!==2||meta.anchor.some((n,i)=>!Number.isInteger(n)||n<0||n>meta.size[i]))fail(`${meta.id}: invalid anchor`);
  if(!isRecord(meta.animations))fail(`${meta.id}: animations must be an object`);
  for(const [id,animation] of Object.entries(meta.animations)) {
    if(!/^[a-z][a-z0-9_]*$/.test(id)||!isRecord(animation)||!Number.isFinite(animation.fps)||animation.fps<=0||animation.fps>60||typeof animation.loop!=='boolean'||!Array.isArray(animation.frames)||!animation.frames.length||animation.frames.some(index=>!Number.isInteger(index)||index<0||index>=meta.frames))fail(`${meta.id}: invalid animation ${id}`);
  }
  if(meta.nineSlice && (!Array.isArray(meta.nineSlice)||meta.nineSlice.length!==4||meta.nineSlice.some(n=>!Number.isInteger(n)||n<0)||meta.nineSlice[0]+meta.nineSlice[2]>meta.size[0]||meta.nineSlice[1]+meta.nineSlice[3]>meta.size[1]))fail(`${meta.id}: invalid nineSlice`);
  return meta;
}
export function validatePixels(canvas,palette,id='image') {
  const allowed=new Set(Object.values(palette.colors).map(hex=>hex.slice(1)));
  for(let i=0;i<canvas.data.length;i+=4) {
    const alpha=canvas.data[i+3];
    if(alpha!==0&&alpha!==255)fail(`${id}: non-binary alpha at pixel ${i/4}`);
    if(alpha===0) {if(canvas.data[i]||canvas.data[i+1]||canvas.data[i+2])fail(`${id}: transparent RGB must be zero`);continue;}
    const rgb=Buffer.from(canvas.data.subarray(i,i+3)).toString('hex');
    if(!allowed.has(rgb))fail(`${id}: off-palette color #${rgb}`);
  }
}
export async function renderArt({root=ROOT}={}) {
  const art=join(root,'resources/art');
  const palette=validatePalette(JSON.parse(await readFile(join(art,'palette.json'),'utf8')));
  const definitions=[];
  for(const file of await filesBelow(join(art,'source'))) {
    if(file.endsWith('.json')) {
      const source=JSON.parse(await readFile(file,'utf8'));
      if(source.format!=='art/1'||!Array.isArray(source.frames))fail(`Invalid character source: ${relative(root,file)}`);
      definitions.push({meta:{...source,frames:source.frames.length},draw:(_g,{frame})=>characterFrame(source.frames[frame],palette,source.size)});
    } else if(file.endsWith('.mjs')) {
      const module=await import(pathToFileURL(file).href);
      if(!Array.isArray(module.assets))fail(`Source module must export assets: ${relative(root,file)}`);
      definitions.push(...module.assets);
    }
  }
  if(!definitions.length)fail('No art sources found');
  definitions.sort((a,b)=>a.meta.id<b.meta.id?-1:a.meta.id>b.meta.id?1:0);
  const files=new Map(),assets=[],canvases=new Map(),ids=new Set();
  for(const definition of definitions) {
    const meta=validateMeta({...definition.meta,animations:definition.meta.animations??{}});
    if(ids.has(meta.id))fail(`Duplicate art id: ${meta.id}`);ids.add(meta.id);
    const [width,height]=meta.size, strip=new PixelCanvas(width*meta.frames,height,palette);
    for(let frame=0;frame<meta.frames;frame++) {
      let canvas=new PixelCanvas(width,height,palette);
      canvas=definition.draw(canvas,{frame,seed:0})??canvas;
      if(canvas.width!==width||canvas.height!==height)fail(`${meta.id}: rendered frame has wrong dimensions`);
      validatePixels(canvas,palette,meta.id);strip.stamp(canvas,frame*width,0);
    }
    const file=meta.id.replaceAll('.','/')+'.png',bytes=encodePNG(strip);
    if(bytes.length>=MAX_FILE_BYTES)fail(`${meta.id}: PNG must be below 2 MB`);
    files.set(file,bytes);canvases.set(meta.id,strip);
    assets.push({id:meta.id,file,size:meta.size,frames:meta.frames,anchor:meta.anchor,animations:meta.animations,...(meta.nineSlice?{nineSlice:meta.nineSlice}:{}),hash:sha256(bytes)});
  }
  const manifest={format:'art/1',assets};files.set('manifest.json',json(manifest));
  return {manifest,files,palette,canvases};
}
export async function buildArt(options={}) {
  const root=options.root??ROOT,result=await renderArt({root});
  for(const [file,bytes] of result.files){const path=join(root,'resources/art/export',file);await mkdir(dirname(path),{recursive:true});await writeFile(path,bytes);}
  return result;
}
const referenceKeys=new Set(['art','art_id','artId','art_ids','artIds','texture','texture_id','sprite','image','image_id']);
export function findArtReferences(value,knownIds,refs=new Set(),explicit=false) {
  if(typeof value==='string') {if(explicit||knownIds.has(value))refs.add(value);}
  else if(Array.isArray(value))for(const item of value)findArtReferences(item,knownIds,refs,explicit);
  else if(isRecord(value))for(const [key,item] of Object.entries(value))findArtReferences(item,knownIds,refs,referenceKeys.has(key));
  return refs;
}
export async function verifyArt({root=ROOT,warn=console.warn}={}) {
  const result=await renderArt({root}),exportRoot=join(root,'resources/art/export');
  for(const [file,expected] of result.files) {
    let actual;try{actual=await readFile(join(exportRoot,file));}catch(error){if(error.code==='ENOENT')fail(`Missing art output: ${file}; run art:build`);throw error;}
    if(!actual.equals(expected))fail(`Art output differs from source: ${file}; run art:build`);
    if(file.endsWith('.png')){
      const decoded=decodePNG(actual),meta=result.manifest.assets.find(asset=>asset.file===file);
      if(decoded.width!==meta.size[0]*meta.frames||decoded.height!==meta.size[1])fail(`${meta.id}: strip dimensions mismatch`);
      validatePixels(decoded,result.palette,meta.id);
      if(sha256(actual)!==meta.hash)fail(`${meta.id}: hash mismatch`);
    }
  }
  const ids=new Set(result.manifest.assets.map(asset=>asset.id)),refs=new Set();
  for(const file of await filesBelow(join(root,'content')))if(file.endsWith('.json'))findArtReferences(JSON.parse(await readFile(file,'utf8')),ids,refs);
  for(const ref of refs)if(!ids.has(ref))fail(`Missing art reference in content: ${ref}`);
  // Runtime ids count as used, without making the standalone art library depend on Godot.
  for(const file of await filesBelow(join(root,'godot/scripts')))if(file.endsWith('.gd')){const code=await readFile(file,'utf8');for(const id of ids)if(code.includes(`"${id}"`)||code.includes(`'${id}'`))refs.add(id);}
  for(const id of ids)if(!refs.has(id))warn(`Art warning: ${id} is not yet referenced by content or runtime`);
  return result;
}
// Tiny original review-label alphabet. Never used for game text.
const glyphs={
 A:['010','101','111','101','101'],B:['110','101','110','101','110'],C:['011','100','100','100','011'],D:['110','101','101','101','110'],E:['111','100','110','100','111'],F:['111','100','110','100','100'],G:['011','100','101','101','011'],H:['101','101','111','101','101'],I:['111','010','010','010','111'],J:['001','001','001','101','010'],K:['101','101','110','101','101'],L:['100','100','100','100','111'],M:['101','111','111','101','101'],N:['101','111','111','111','101'],O:['010','101','101','101','010'],P:['110','101','110','100','100'],Q:['010','101','101','111','011'],R:['110','101','110','101','101'],S:['011','100','010','001','110'],T:['111','010','010','010','010'],U:['101','101','101','101','111'],V:['101','101','101','101','010'],W:['101','101','111','111','101'],X:['101','101','010','101','101'],Y:['101','101','010','010','010'],Z:['111','001','010','100','111'],
 '0':['111','101','101','101','111'],'1':['010','110','010','010','111'],'2':['110','001','010','100','111'],'3':['110','001','010','001','110'],'4':['101','101','111','001','001'],'5':['111','100','110','001','110'],'6':['011','100','111','101','111'],'7':['111','001','010','010','010'],'8':['111','101','111','101','111'],'9':['111','101','111','001','110'],'.':['000','000','000','000','010'],'/':['001','001','010','100','100'],'-':['000','000','111','000','000'],':':['000','010','000','010','000'],' ':['000','000','000','000','000'],
};
function label(canvas,text,x,y,color='paper1') {
  for(const character of text.toUpperCase()){const glyph=glyphs[character];if(!glyph)fail(`Unknown review glyph: ${character}`);glyph.forEach((row,dy)=>[...row].forEach((bit,dx)=>{if(bit==='1')canvas.px(x+dx,y+dy,color);}));x+=4;}
}
export async function sheetArt({root=ROOT}={}) {
  const result=await verifyArt({root,warn:()=>{}}),g=new PixelCanvas(648,450,result.palette).fill('ink');
  label(g,'SWITCHEROO / ORIGINAL CODE-DRAWN PIXEL ART / D0',8,7,'gold2');
  const cupper=result.canvases.get('char.cupper');
  if(!cupper||!result.canvases.has('stage.frame'))fail('D0 sheet requires char.cupper and stage.frame');
  for(let frame=0;frame<4;frame++) {
    const tile=new PixelCanvas(24,32,result.palette);
    for(let y=0;y<32;y++)tile.data.set(cupper.data.subarray((y*cupper.width+frame*24)*4,(y*cupper.width+frame*24+24)*4),y*24*4);
    const x=12+frame*56;g.rect(x-4,19,32,36,'night1');g.stamp(tile,x,21);label(g,`IDLE ${frame}`,x-1,59,'silver1');
    if(frame===0){
      const silhouette=new PixelCanvas(24,32,result.palette).stamp(tile,0,0).recolor(Object.fromEntries(Object.keys(result.palette.colors).map(name=>[name,'gold3'])));
      g.stamp(silhouette,300,21);label(g,'SILHOUETTE',291,59,'silver1');
      for(const [i,name] of ['dream','dark_slot','ghost'].entries()) {
        const preview=new PixelCanvas(24,32,result.palette).stamp(tile,0,0).recolor(result.palette.swaps[name]);
        g.rect(400+i*80,19,32,36,'night1');g.stamp(preview,404+i*80,21);label(g,name.replaceAll('_',' '),400+i*80,59,'silver1');
      }
    }
  }
  label(g,'CHAR.CUPPER / 24X32 / 4 FPS',8,69,'gold2');label(g,'STAGE.FRAME / 640X360',340,69,'gold2');
  g.stamp(result.canvases.get('stage.frame'),4,80);
  label(g,'3X NEAREST / 47 COLORS / BINARY ALPHA / NO EXTERNAL IMAGES',8,444,'silver1');
  const enlarged=new PixelCanvas(g.width*3,g.height*3,result.palette).stamp(g,0,0,3),bytes=encodePNG(enlarged);
  if(bytes.length>=MAX_FILE_BYTES)fail('Contact sheet must be below 2 MB');
  const file=join(root,'resources/art/export/sheets/d0-contact.png');await mkdir(dirname(file),{recursive:true});await writeFile(file,bytes);
  return {file,bytes:bytes.length,width:enlarged.width,height:enlarged.height};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  try {
    const command=process.argv[2];
    if(process.argv.length!==3||!['build','verify','sheet'].includes(command))fail('Usage: node tools/resources/art.mjs build|verify|sheet');
    const result=await ({build:buildArt,verify:verifyArt,sheet:sheetArt}[command])();
    console.log(command==='sheet'?`Art sheet: ${relative(ROOT,result.file)} (${result.width}x${result.height}, ${result.bytes} bytes)`:`Art ${command}: ${result.manifest.assets.length} assets OK`);
  }catch(error){console.error(`Art error: ${error.message}`);process.exitCode=1;}
}
