import fs from 'node:fs';
import { cues } from '../../resources/audio/cues/d0.ts';
import { renderCue, wav, metrics } from '../../resources/audio/synth.ts';
import { at, hash } from '../lib/paths.mjs';
const mode=process.argv[2];if(!['build','check'].includes(mode))throw Error('Expected build or check');
const dir=at('resources/audio/export');fs.mkdirSync(dir,{recursive:true});const assets=[];
for(const cue of cues){const samples=renderCue(cue),bytes=wav(samples,cue.rate),m=metrics(samples);
 if(!bytes.equals(wav(renderCue(cue),cue.rate)))throw Error('Non-deterministic '+cue.id);
 const target=cue.music?-20:-18,tolerance=cue.music?2:3;
 if(m.peak_dbfs > -1 || Math.abs(m.rms_dbfs-target)>tolerance || m.first!==0 || m.last!==0 || bytes.length>=2_000_000)throw Error('Invalid audio '+cue.id+JSON.stringify(m));
 const file=at('resources/audio/export',cue.file);
 if(mode==='build')fs.writeFileSync(file,bytes);else if(!fs.readFileSync(file).equals(bytes))throw Error('Stale audio '+cue.id);
 assets.push({id:cue.id,file:cue.file,sample_rate:cue.rate,channels:1,format:'PCM16',seconds:cue.seconds,loop:cue.music,hash:hash(bytes),...m});
}
const manifest=JSON.stringify({format:'audio/1',assets},null,2)+'\n';const target=at('resources/audio/export/manifest.json');
if(mode==='build')fs.writeFileSync(target,manifest);else if(fs.readFileSync(target,'utf8')!==manifest)throw Error('Stale audio manifest');
fs.mkdirSync(at('artifacts/reports'),{recursive:true});fs.writeFileSync(at('artifacts/reports/audio-d0.json'),JSON.stringify({scope:'D0 synthesized audio numerical checks; listening is a separate manual check',passed:true,assets},null,2)+'\n');
console.log(`audio:${mode}: ${assets.length} deterministic PCM16 cues; peak/RMS/endpoints PASS`);
