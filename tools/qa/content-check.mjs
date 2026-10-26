import fs from 'node:fs';
import {at,inside} from '../lib/paths.mjs';

const idPattern = /^[a-z][a-z0-9_.]*$/;
const collections = ['duels','props','foes','items','held_items','rehearsals','roads','investigations','upgrades','marks','acts','clues'];
const kinds = new Set(['hit','move','touch','extinguish','pole','roll','guard','rain','steal','check','swap']);
const targets = new Set(['player','self','adjacent_empty','adjacent_unmarked_prop','farthest_not_heavy','nearest_lit_lamp','farthest_dark']);
const fail = message => { throw Error(message); };
const integer = (n,min,max,label) => { if (!Number.isInteger(n) || n < min || n > max) fail(`Invalid ${label}`); };

export function validateContent(registry, read, artIds, audioIds) {
 if (registry.format !== 'content/1' || !Array.isArray(registry.files) || new Set(registry.files).size !== registry.files.length) fail('Invalid content registry');
 const documents = [];
 function visit(x) {
  if (!x || typeof x !== 'object') return;
  for (const [key,value] of Object.entries(x)) {
   if (key === 'art_ids') for (const id of value) if (!artIds.has(id)) fail(`Missing art ${id}`);
   if (key === 'audio_ids') for (const id of value) if (!audioIds.has(id)) fail(`Missing audio ${id}`);
   if (key === 'signboard') {
    const blanks = Object.values(value.blanks ?? {});
    if (!blanks.length || !blanks.some(blank => blank.clue === null)) fail('Rule needs a stage-only blank');
   }
   if (key === 'slots' && value !== 5) fail('Stage must have 5 slots');
   visit(value);
  }
 }
 for (const file of registry.files) {
  inside(at('content'),file);
  const data = read(file);
  if (!data || typeof data !== 'object' || Array.isArray(data)) fail(`Invalid content document ${file}`);
  documents.push(data); visit(data);
 }
 const groups = Object.fromEntries(collections.map(key => [key,documents.flatMap(doc => Array.isArray(doc[key]) ? doc[key] : [])]));
 const maps = Object.fromEntries(collections.map(key => [key,new Map()]));
 for (const key of collections) for (const record of groups[key]) {
  if (!idPattern.test(record.id)) fail(`Invalid content id in ${key}`);
  if (maps[key].has(record.id)) fail(`Duplicate ${key} id ${record.id}`);
  maps[key].set(record.id,record);
 }
 const d1 = groups.duels.some(duel => duel.id === 'duel.prologue');
 if (!d1) return registry.files.length;
 function reference(key,id,label) { if (!maps[key].has(id)) fail(`Missing ${label ?? key} ${id}`); return maps[key].get(id); }
 function intent(value,environment=false) {
  if (!value || !kinds.has(value.kind)) fail('Invalid intent kind');
  if (value.amount !== undefined) integer(value.amount,0,50,'intent amount');
  if (environment) integer(value.slot,0,4,'intent slot');
  else if (!targets.has(value.target)) fail(`Invalid intent target ${value.target}`);
  if (value.fallback) intent(value.fallback);
 }
 function entity(value) {
  if (!value || !idPattern.test(value.id) || !['player','foe','rival','prop'].includes(value.kind)) fail('Invalid stage entity');
  if (!value.name || !Array.isArray(value.marks)) fail(`Incomplete entity ${value.id}`);
  integer(value.hp,0,100,'entity hp'); integer(value.max_hp,0,100,'entity maximum hp');
  if (value.hp > value.max_hp || (value.hp === 0 && !value.unbreakable)) fail(`Invalid entity health ${value.id}`);
  integer(value.guard,0,50,'entity guard');
  if (value.item) reference('held_items',value.item,'held item');
  if (value.archetype && !maps.foes.has(value.archetype) && !maps.props.has(value.archetype)) fail(`Missing archetype ${value.archetype}`);
  if (!Array.isArray(value.cycle)) fail(`Missing intent cycle ${value.id}`);
  value.cycle.forEach(cycle => intent(cycle));
 }
 function stage(value) {
  if (value.slots !== 5 || !Array.isArray(value.layout) || value.layout.length !== 5) fail(`Invalid five-slot layout ${value.id}`);
  const residents = value.layout.filter(Boolean);
  residents.forEach(entity);
  if (new Set(residents.map(item => item.id)).size !== residents.length) fail(`Duplicate stage entity ${value.id}`);
  if (residents.filter(item => item.kind === 'player' && item.id === 'char.aming').length !== 1) fail(`Stage must have one player ${value.id}`);
  integer(value.act,1,3,'act number');
  for (const key of ['hp','strike','guard','reach']) integer(value.player?.[key],1,30,`player ${key}`);
  for (const [item,count] of Object.entries(value.player.items ?? {})) { reference('items',item,'item'); integer(count,0,10,'item count'); }
 }
 for (const value of [...groups.duels,...groups.roads]) {
  stage(value);
  if (!['none','prologue','thief','ferryman'].includes(value.rule)) fail(`Invalid duel rule ${value.rule}`);
  value.intent_cycle.forEach(cycle => intent(cycle));
  if (value.reward_mark) reference('marks',value.reward_mark,'reward mark');
  if (value.rival && !value.layout.some(entity => entity?.id === value.rival && entity.kind === 'rival')) fail(`Missing rival in ${value.id}`);
  if (value.signboard) {
   const investigation = reference('investigations',value.investigation,'investigation');
   if (investigation.act !== value.act) fail('Rule investigation must belong to the same act');
   for (const [key,blank] of Object.entries(value.signboard.blanks)) {
    if (!blank.word || !blank.stage || !value.signboard.text.includes(`{${key}}`)) fail(`Invalid signboard blank ${key}`);
    if (blank.clue !== null) {
     reference('clues',blank.clue,'clue');
     if (!investigation.hotspots.some(spot => spot.clue === blank.clue)) fail(`Unreachable clue ${blank.clue}`);
    }
   }
  }
 }
 for (const value of groups.rehearsals) {
  stage(value);
  if (!['position','item'].includes(value.mode)) fail('Invalid rehearsal swap mode');
  if (!['rain','geese','cart','purse','key','light'].includes(value.goal_kind)) fail('Invalid rehearsal goal');
  integer(value.swaps,1,2,'rehearsal swaps');
  if (typeof value.main_allowed !== 'boolean' || !value.goal || !value.hint) fail('Incomplete rehearsal instructions');
  for (const action of value.intents) {
   intent(action,true);
   if (action.actor !== 'environment' && !value.layout.some(entity => entity?.id === action.actor)) fail(`Missing rehearsal actor ${action.actor}`);
  }
 }
 for (const value of groups.investigations) {
  integer(value.act,1,3,'investigation act'); integer(value.hotspots?.length,4,6,'hotspot count');
  if (new Set(value.hotspots.map(spot=>spot.id)).size !== value.hotspots.length) fail('Duplicate hotspot');
  for (const spot of value.hotspots) {
   if (!spot.name || !Array.isArray(spot.lines) || !spot.lines.length || spot.lines.length > 4 || spot.lines.some(line => typeof line !== 'string' || !line)) fail('Invalid hotspot dialogue');
   if (spot.clue) reference('clues',spot.clue,'clue');
  }
 }
 for (const value of groups.acts) {
  integer(value.number,1,3,'act number');
  if (reference('duels',value.duel,'act duel').act !== value.number || reference('investigations',value.investigation,'act investigation').act !== value.number) fail('Act flow reference belongs to another act');
  if (value.rehearsals.length !== 2 || new Set(value.rehearsals).size !== 2) fail('Act requires two distinct rehearsals');
  for (const id of value.rehearsals) if (reference('rehearsals',id,'act rehearsal').act !== value.number) fail('Rehearsal belongs to another act');
  if (value.road && reference('roads',value.road,'act road').act !== value.number) fail('Road belongs to another act');
  if (!value.letter?.body || value.letter.choices?.length !== 3 || new Set(value.letter.choices).size !== 3) fail('Letter requires exactly three distinct endings');
  for (const key of ['opening','curtain','dream']) if (!value[key]?.length) fail(`Missing story section ${key}`);
  for (const key of ['opening','after_tutorial','curtain','dream']) for (const page of value[key]) if (!page.speaker || !page.text || [...page.text].length > 50) fail(`Invalid story page ${value.id}/${key}`);
 }
 for (const value of groups.upgrades) { integer(value.cost,1,8,'upgrade cost'); integer(value.limit,1,2,'upgrade limit'); integer(value.amount,1,4,'upgrade amount'); }
 for (const value of groups.marks) reference('duels',value.source,'mark source');
 for (const [key,count] of Object.entries({duels:3,rehearsals:6,roads:2,investigations:3,foes:3,upgrades:4,marks:2,acts:3})) if (groups[key].length !== count) fail(`D1 requires ${count} ${key}`);
 return registry.files.length;
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
 const read = file => JSON.parse(fs.readFileSync(at('content',file),'utf8'));
 const ids = kind => new Set(JSON.parse(fs.readFileSync(at(`resources/${kind}/export/manifest.json`),'utf8')).assets.map(asset => asset.id));
 console.log(`content:check: ${validateContent(read('registry.json'),read,ids('art'),ids('audio'))} registered files, schema + semantic references PASS`);
}
