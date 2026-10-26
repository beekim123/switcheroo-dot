import test from 'node:test';import assert from 'node:assert/strict';import {validateContent} from '../tools/qa/content-check.mjs';import {inside} from '../tools/lib/paths.mjs';
const reg={format:'content/1',files:['data/a.json']};const valid={slots:5,art_ids:['a'],audio_ids:['b']};
test('registered content references validate',()=>assert.equal(validateContent(reg,()=>valid,new Set(['a']),new Set(['b'])),1));
test('missing art is rejected',()=>assert.throws(()=>validateContent(reg,()=>valid,new Set(),new Set(['b'])),/Missing art/));
test('rules require an observed-on-stage blank',()=>assert.throws(()=>validateContent(reg,()=>({signboard:{blanks:{x:{clue:'a'}}}}),new Set(),new Set()),/stage-only/));
test('relative paths cannot escape roots',()=>{assert.throws(()=>inside('/safe','../escape'));assert.throws(()=>inside('/safe','/escape'));});

import fs from 'node:fs';
const contentRoot = new URL('../content/', import.meta.url);
const fullRegistry = JSON.parse(fs.readFileSync(new URL('registry.json',contentRoot),'utf8'));
function dataset() { return Object.fromEntries(fullRegistry.files.map(file => [file,JSON.parse(fs.readFileSync(new URL(file,contentRoot),'utf8'))])); }
const artIds = new Set(['stage.frame','char.cupper']);
const audioIds = new Set(['sfx.cup_down','sfx.cup_up','sting.exposed','music.d0_theme']);
function validateDataset(data) { return validateContent(fullRegistry,file=>data[file],artIds,audioIds); }
function corrupt(edit,pattern) { const data=dataset(); edit(data); assert.throws(()=>validateDataset(data),pattern); }
test('D1 authored content validates complete three-act graph',()=>assert.equal(validateDataset(dataset()),12));
test('D1 stage cannot have six positions',()=>corrupt(d=>d['data/duels.json'].duels[0].layout.push(null),/five-slot/));
test('D1 stage cannot duplicate resident ids',()=>corrupt(d=>d['data/duels.json'].duels[0].layout[4].id='foe.moondust_a',/Duplicate stage/));
test('D1 duplicate content ids are rejected',()=>corrupt(d=>d['data/upgrades.json'].upgrades[1].id='up.reach',/Duplicate upgrades/));
test('D1 clue must be obtainable in the matching investigation',()=>corrupt(d=>d['data/duels.json'].duels[1].signboard.blanks.touch.clue='clue.ferry.fish',/Unreachable clue/));
test('D1 signboard placeholders must match blanks',()=>corrupt(d=>d['data/duels.json'].duels[1].signboard.text='没有空格',/Invalid signboard/));
test('D1 unknown held items are rejected',()=>corrupt(d=>d['data/duels.json'].duels[0].layout[0].item='held.typo',/Missing held item/));
test('D1 environment intents use zero-based valid positions',()=>corrupt(d=>d['data/rehearsals.json'].rehearsals[0].intents[0].slot=5,/Invalid intent slot/));
test('D1 rehearsal actors must exist',()=>corrupt(d=>d['data/rehearsals.json'].rehearsals[1].intents[0].actor='foe.missing',/Missing rehearsal actor/));
test('D1 letters require exactly three choices',()=>corrupt(d=>d['data/acts.json'].acts[0].letter.choices.pop(),/three distinct/));
test('D1 act references cannot silently cross acts',()=>corrupt(d=>d['data/acts.json'].acts[0].duel='duel.thief',/another act/));
test('D1 empty invulnerable props remain legal',()=>{const d=dataset();assert.equal(d['data/duels.json'].duels[0].layout[3].hp,0);assert.doesNotThrow(()=>validateDataset(d));});
test('D1 no rule can prefill every blank from clues',()=>{for(const duel of dataset()['data/duels.json'].duels)if(duel.signboard)assert.ok(Object.values(duel.signboard.blanks).some(blank=>blank.clue===null));});
