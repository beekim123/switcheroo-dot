import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir, mkdtemp, cp, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import { PixelCanvas, characterFrame } from '../resources/art/lib/pixel.mjs';
import { crc32, encodePNG, decodePNG } from '../resources/art/lib/png.mjs';
import { ROOT, validatePalette, validateMeta, validatePixels, findArtReferences, renderArt, verifyArt, sheetArt } from '../tools/resources/art.mjs';

const palette=JSON.parse(await readFile(join(ROOT,'resources/art/palette.json'),'utf8'));
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const meta={id:'char.test',size:[24,32],frames:4,anchor:[12,32],animations:{idle:{fps:4,loop:true,frames:[0,1,2,3]}}};
async function fixture() {
  await mkdir(join(ROOT,'.cache/art'),{recursive:true});
  const root=await mkdtemp(join(ROOT,'.cache/art/test-'));
  await cp(join(ROOT,'resources/art'),join(root,'resources/art'),{recursive:true});
  return root;
}

test('palette has the exact 47 documented RGB colors and complete safe swaps',async()=>{
  validatePalette(palette);
  const document=await readFile(join(ROOT,'docs/art/art-direction.md'),'utf8');
  const documented=Object.fromEntries([...document.matchAll(/`([a-z0-9_]+) (#[0-9a-f]{6})`/g)].map(match=>[match[1],match[2]]));
  assert.equal(Object.keys(documented).length,47);
  assert.deepEqual(palette.colors,documented);
  assert.ok(Object.values(palette.swaps.dream).every(name=>/^(night|silver)/.test(name)));
  assert.ok(Object.values(palette.swaps.ghost).every(name=>name.startsWith('gold')));
  const broken=structuredClone(palette);broken.swaps.ghost.ink='missing';assert.throws(()=>validatePalette(broken),/swap target/);
});

test('PNG codec round-trips RGBA and produces byte-identical output',()=>{
  const canvas=new PixelCanvas(8,7,palette).fill('night0').rect(2,1,4,4,'gold2').px(0,0,'.');
  const first=encodePNG(canvas),second=encodePNG(canvas),decoded=decodePNG(first);
  assert.deepEqual(first,second);assert.equal(decoded.width,8);assert.equal(decoded.height,7);assert.deepEqual(decoded.data,canvas.data);
  assert.equal(crc32(Buffer.from('123456789')),0xcbf43926);
});

test('PNG decoder rejects corrupt CRC, truncation, unsupported layout and oversized dimensions',()=>{
  const valid=encodePNG(new PixelCanvas(2,2,palette).fill('ink'));
  const corrupt=Buffer.from(valid);corrupt[45]^=1;assert.throws(()=>decodePNG(corrupt),/CRC/);
  assert.throws(()=>decodePNG(valid.subarray(0,-3)),/Truncated/);
  assert.throws(()=>decodePNG(Buffer.from('not png')),/signature/);
  const wrongType=Buffer.from(valid);wrongType[25]=2;wrongType.writeUInt32BE(crc32(wrongType.subarray(12,29)),29);assert.throws(()=>decodePNG(wrongType),/RGBA8/);
  assert.throws(()=>encodePNG({width:0,height:1,data:new Uint8Array()}),/dimensions/);
  assert.throws(()=>encodePNG({width:100000,height:100000,data:new Uint8Array()}),/dimensions/);
  assert.throws(()=>encodePNG({width:2,height:2,data:new Uint8Array(2)}),/length/);
});

test('PNG decoder supports all five standard scanline filters',()=>{
  const canvas=new PixelCanvas(3,5,palette);
  for(let y=0;y<5;y++)for(let x=0;x<3;x++)canvas.px(x,y,['gold1','velvet2','night2'][(x+y)%3]);
  const stride=12,raw=Buffer.alloc(65);
  for(let y=0;y<5;y++){
    raw[y*13]=y;
    for(let x=0;x<stride;x++){
      const i=y*stride+x,a=x>=4?canvas.data[i-4]:0,b=y?canvas.data[i-stride]:0,c=y&&x>=4?canvas.data[i-stride-4]:0;
      const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);
      const predictor=[0,a,b,Math.floor((a+b)/2),pa<=pb&&pa<=pc?a:pb<=pc?b:c][y];
      raw[y*13+x+1]=(canvas.data[i]-predictor)&255;
    }
  }
  const original=encodePNG(canvas),compressed=deflateSync(raw),chunk=Buffer.alloc(compressed.length+12);
  chunk.writeUInt32BE(compressed.length,0);chunk.write('IDAT',4);compressed.copy(chunk,8);chunk.writeUInt32BE(crc32(chunk.subarray(4,-4)),chunk.length-4);
  const filtered=Buffer.concat([original.subarray(0,33),chunk,original.subarray(-12)]);
  assert.deepEqual(decodePNG(filtered).data,canvas.data);
});

test('pixel canvas enforces integer palette drawing, clipping and binary-alpha stamping',()=>{
  const canvas=new PixelCanvas(5,5,palette);
  assert.throws(()=>canvas.px(0.5,1,'gold1'),/integers/);assert.throws(()=>canvas.fill('#ffffff'),/Unknown palette/);
  assert.throws(()=>canvas.rect(0,0,-1,1,'gold1'),/negative/);assert.throws(()=>canvas.stamp(canvas,0,0,0),/positive/);
  canvas.rect(-2,-2,3,3,'gold2');assert.equal(canvas.data[3],255);assert.equal(canvas.data[7],0);
  canvas.line(0,4,4,0,'silver2');canvas.ellipse(1,1,3,3,'velvet1');canvas.polygon([[0,0],[4,0],[2,4]],'indigo1');validatePixels(canvas,palette);
  const translucent=new PixelCanvas(1,1,palette);translucent.data[3]=128;assert.throws(()=>canvas.stamp(translucent,0,0),/binary alpha/);
});

test('character frames reject malformed rows and unknown palette symbols',()=>{
  assert.throws(()=>characterFrame(['KK'],palette,[3,1]),/dimensions/);
  assert.throws(()=>characterFrame(['?'],palette,[1,1]),/Unknown character/);
  assert.deepEqual(characterFrame(['K.'],palette,[2,1]).data.subarray(4),new Uint8Array(4));
});

test('metadata rejects invalid frames, anchors, animation references and nine-slices',()=>{
  validateMeta(meta);
  assert.throws(()=>validateMeta({...meta,id:'../bad'}),/art id/);
  assert.throws(()=>validateMeta({...meta,frames:0}),/frame count/);
  assert.throws(()=>validateMeta({...meta,size:[24.5,32]}),/frame size/);
  assert.throws(()=>validateMeta({...meta,anchor:[25,32]}),/anchor/);
  assert.throws(()=>validateMeta({...meta,animations:{idle:{fps:4,loop:true,frames:[4]}}}),/animation/);
  assert.throws(()=>validateMeta({...meta,nineSlice:[20,0,20,0]}),/nineSlice/);
});

test('pixel validation rejects off-palette colors, hidden RGB and partial alpha',()=>{
  const canvas=new PixelCanvas(1,1,palette).fill('gold2');canvas.data[0]=0;assert.throws(()=>validatePixels(canvas,palette),/off-palette/);
  canvas.data[3]=120;assert.throws(()=>validatePixels(canvas,palette),/non-binary/);
  canvas.data[3]=0;assert.throws(()=>validatePixels(canvas,palette),/transparent RGB/);
});

test('D0 sources render exactly two deterministic, correctly sized and hashed assets',async()=>{
  const first=await renderArt(),second=await renderArt();
  assert.deepEqual(first.manifest,second.manifest);
  assert.deepEqual(first.manifest.assets.map(asset=>asset.id),['char.cupper','stage.frame']);
  for(const asset of first.manifest.assets){const bytes=first.files.get(asset.file);assert.deepEqual(bytes,second.files.get(asset.file));assert.equal(hash(bytes),asset.hash);assert.ok(bytes.length<2_000_000);const png=decodePNG(bytes);assert.equal(png.width,asset.size[0]*asset.frames);assert.equal(png.height,asset.size[1]);validatePixels(png,palette);}
  const cupper=first.manifest.assets[0];assert.deepEqual(cupper.size,[24,32]);assert.equal(cupper.frames,4);assert.equal(cupper.animations.idle.fps,4);
  const source=JSON.parse(await readFile(join(ROOT,'resources/art/source/char/cupper.json'),'utf8'));
  assert.equal(new Set(source.frames.map(frame=>JSON.stringify(frame))).size,4);
});

test('reference scanner distinguishes explicit art references from logical entity ids',()=>{
  const refs=findArtReferences({id:'prop.logical_only',art_ids:['char.cupper','char.missing'],data:{artId:'stage.frame'}},new Set(['char.cupper','stage.frame']));
  assert.deepEqual([...refs].sort(),['char.cupper','char.missing','stage.frame']);
});

test('verify is read-only and catches stale PNGs, manifest drift and missing content art',async()=>{
  const root=await fixture();
  try {
    const output=join(root,'resources/art/export/char/cupper.png'),original=await readFile(output);
    await verifyArt({root,warn:()=>{}});assert.deepEqual(await readFile(output),original);
    await writeFile(output,Buffer.concat([original,Buffer.from([0])]));await assert.rejects(verifyArt({root,warn:()=>{}}),/differs from source/);await writeFile(output,original);
    await mkdir(join(root,'content/data'),{recursive:true});await writeFile(join(root,'content/data/bad.json'),JSON.stringify({art_ids:['char.not_real']}));
    await assert.rejects(verifyArt({root,warn:()=>{}}),/Missing art reference/);await rm(join(root,'content/data/bad.json'));
    const manifest=join(root,'resources/art/export/manifest.json');await writeFile(manifest,'{}\n');await assert.rejects(verifyArt({root,warn:()=>{}}),/differs from source: manifest/);
  }finally{await rm(root,{recursive:true,force:true});}
});

test('review sheet is deterministic 3x nearest-neighbor and below the file limit',async()=>{
  const root=await fixture();
  try {
    const first=await sheetArt({root}),bytes=await readFile(first.file);await sheetArt({root});assert.deepEqual(await readFile(first.file),bytes);
    const png=decodePNG(bytes);assert.equal(png.width,1944);assert.equal(png.height,1350);assert.ok(bytes.length<2_000_000);validatePixels(png,palette);
    for(let y=0;y<png.height;y+=3)for(let x=0;x<png.width;x+=3){const i=(y*png.width+x)*4;for(let dy=0;dy<3;dy++)for(let dx=0;dx<3;dx++){const j=((y+dy)*png.width+x+dx)*4;assert.ok(png.data.subarray(i,i+4).every((channel,k)=>channel===png.data[j+k]));}}
  }finally{await rm(root,{recursive:true,force:true});}
});
