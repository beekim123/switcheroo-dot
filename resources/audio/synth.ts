import type { Cue } from './cues/d0.ts';
export function seeded(seed: number) { let s=seed>>>0; return () => {s=(Math.imul(s,1664525)+1013904223)>>>0; return s/4294967296*2-1;}; }
const sine=(hz:number,t:number)=>Math.sin(2*Math.PI*hz*t);
export function voice(kind:string,t:number, noise:number,hz=440):number {
 if(kind==='gong') return [1,1.47,2.09,2.81,3.73].reduce((s,k,j)=>s+sine(148*k*(1-.012*t),t)*Math.exp(-t*(1.4+j*.45))/(j+1),0);
 if(kind==='cymbal') return noise*Math.exp(-t*14)*(Math.sin(t*6500)+.5);
 if(kind==='wood') return (.7*sine(690,t)+.3*sine(1070,t)+.12*noise)*Math.exp(-t*24);
 if(kind==='bell') return (sine(720,t)+.4*sine(1447,t))*Math.exp(-t*16);
 return (sine(hz,t)+.23*sine(hz*2,t)+.1*sine(hz*3,t))*Math.exp(-t*3.4);
}
export function renderCue(cue:Cue):Int16Array {
 const n=Math.round(cue.rate*cue.seconds), raw=new Float64Array(n), rnd=seeded(0x53574954);
 for(let i=0;i<n;i++) {const t=i/cue.rate;let v=0;
  if(cue.kind==='theme') {const beat=Math.floor(t), local=t-beat; const midi=cue.notes![beat];v=voice('pluck',local,rnd(),440*2**((midi-69)/12));v+=.2*voice('pluck',local,rnd(),130.8128);}
  else v=voice(cue.kind,t,rnd());
  const edge=Math.min(1,i/(cue.rate*.004),(n-1-i)/(cue.rate*.02));raw[i]=v*Math.max(0,edge);
 }
 const rms=Math.sqrt(raw.reduce((s,x)=>s+x*x,0)/n),peak=raw.reduce((s,x)=>Math.max(s,Math.abs(x)),0);
 const gain=Math.min(10**((cue.music?-20:-18)/20)/rms,.88/peak);
 return Int16Array.from(raw,x=>Math.round(x*gain*32767));
}
export function wav(samples:Int16Array,rate:number):Buffer {
 const out=Buffer.alloc(44+samples.length*2);out.write('RIFF');out.writeUInt32LE(out.length-8,4);out.write('WAVEfmt ',8);out.writeUInt32LE(16,16);out.writeUInt16LE(1,20);out.writeUInt16LE(1,22);out.writeUInt32LE(rate,24);out.writeUInt32LE(rate*2,28);out.writeUInt16LE(2,32);out.writeUInt16LE(16,34);out.write('data',36);out.writeUInt32LE(samples.length*2,40);samples.forEach((x,i)=>out.writeInt16LE(x,44+i*2));return out;
}
export function metrics(samples:Int16Array) {
 let sum=0,peak=0;for(const x of samples){const v=x/32768;sum+=v*v;peak=Math.max(peak,Math.abs(v));}
 return {peak_dbfs:20*Math.log10(peak),rms_dbfs:20*Math.log10(Math.sqrt(sum/samples.length)),first:samples[0],last:samples.at(-1)};
}
