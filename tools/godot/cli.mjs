import fs from 'node:fs';import {spawnSync} from 'node:child_process';import {at} from '../lib/paths.mjs';
const command=process.argv[2]??'dev',bin=process.env.GODOT_BIN??'godot';
const profile=['test','sim','smoke','integration','content-test'].includes(command)?'qa':command==='shots'?'shots':'play';
const env={...process.env,HOME:at('.local',profile,'home'),XDG_CONFIG_HOME:at('.local',profile,'config'),XDG_DATA_HOME:at('.local',profile,'data'),XDG_CACHE_HOME:at('.cache')};for(const key of ['HOME','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME'])fs.mkdirSync(env[key],{recursive:true});
const version=spawnSync(bin,['--version'],{env,encoding:'utf8'});if(version.status!==0||!version.stdout.trim().startsWith('4.7.2.'))throw Error('Godot 4.7.2 is required. Set GODOT_BIN to that executable.');
const configs={dev:[],import:['--headless','--editor','--import'],test:['--headless','--script','res://tests/run_tests.gd'],sim:['--headless','--script','res://tests/sim_d1.gd'],smoke:['--headless','--script','res://tests/title_smoke.gd'],integration:['--headless','--script','res://tests/journey_smoke.gd'],'content-test':['--headless','--script','res://tests/d1_content_tests.gd'],shots:['--audio-driver','Dummy','--resolution','1280x720','--','--shots']};
if(!Object.hasOwn(configs,command))throw Error('Unknown Godot operation');
const nonInteractive=['test','sim','smoke','import','integration','content-test'].includes(command);
const run=spawnSync(bin,['--path',at('godot'),...configs[command]],nonInteractive?{env,encoding:'utf8'}:{env,stdio:'inherit'});if(run.error)throw run.error;
if(nonInteractive){process.stdout.write(run.stdout??'');process.stderr.write(run.stderr??'');if(/SCRIPT ERROR:|^ERROR:|ObjectDB instances were leaked|Leaked instance:/m.test((run.stdout??'')+(run.stderr??'')))process.exit(1);}
process.exit(run.status??1);
