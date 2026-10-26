import test from 'node:test';import assert from 'node:assert/strict';import {validateContent} from '../tools/qa/content-check.mjs';import {inside} from '../tools/lib/paths.mjs';
const reg={format:'content/1',files:['data/a.json']};const valid={slots:5,art_ids:['a'],audio_ids:['b']};
test('registered content references validate',()=>assert.equal(validateContent(reg,()=>valid,new Set(['a']),new Set(['b'])),1));
test('missing art is rejected',()=>assert.throws(()=>validateContent(reg,()=>valid,new Set(),new Set(['b'])),/Missing art/));
test('rules require an observed-on-stage blank',()=>assert.throws(()=>validateContent(reg,()=>({signboard:{blanks:{x:{clue:'a'}}}}),new Set(),new Set()),/stage-only/));
test('relative paths cannot escape roots',()=>{assert.throws(()=>inside('/safe','../escape'));assert.throws(()=>inside('/safe','/escape'));});
