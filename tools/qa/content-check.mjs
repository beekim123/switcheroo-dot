import fs from 'node:fs';import {at,inside} from '../lib/paths.mjs';
export function validateContent(registry, read, artIds, audioIds){
 if(registry.format!=='content/1'||!Array.isArray(registry.files)||new Set(registry.files).size!==registry.files.length)throw Error('Invalid content registry');
 function visit(x){if(!x||typeof x!=='object')return;
  for(const [k,v]of Object.entries(x)){
   if(k==='art_ids')for(const id of v)if(!artIds.has(id))throw Error(`Missing art ${id}`);
   if(k==='audio_ids')for(const id of v)if(!audioIds.has(id))throw Error(`Missing audio ${id}`);
   if(k==='signboard'){const blanks=Object.values(v.blanks);if(!blanks.length||!blanks.some(b=>b.clue===null))throw Error('Rule needs a stage-only blank');}
   if(k==='slots'&&v!==5)throw Error('Stage must have 5 slots');
   visit(v);
  }
 }
 for(const f of registry.files){inside(at('content'),f);visit(read(f));}return registry.files.length;
}
if(process.argv[1]===new URL(import.meta.url).pathname){
 const read=p=>JSON.parse(fs.readFileSync(at('content',p),'utf8'));
 const ids=kind=>new Set(JSON.parse(fs.readFileSync(at(`resources/${kind}/export/manifest.json`),'utf8')).assets.map(a=>a.id));
 console.log(`content:check: ${validateContent(read('registry.json'),read,ids('art'),ids('audio'))} registered files, semantic references PASS (D0 scope)`);
}
