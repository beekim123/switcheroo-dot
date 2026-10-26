extends SceneTree
const Bots = preload("res://scripts/core/bots.gd")
const Duel = preload("res://scripts/core/duel_rules.gd")
const Solver = preload("res://scripts/core/solver.gd")
const Stage = preload("res://scripts/core/stage_state.gd")
const Journey = preload("res://scripts/core/journey_state.gd")
const Save = preload("res://scripts/services/save_service.gd")
var checks := 0
var failed := 0
var game: Control
var visited_steps: Array=[]

func check(value: bool, label: String) -> void:
 checks+=1
 if not value: failed+=1; push_error(label)

func script_text(path: String) -> String:
 var result := ""
 for name in DirAccess.get_files_at(path):
  if name.ends_with(".gd"): result+=FileAccess.get_file_as_string(path+"/"+name)
 for name in DirAccess.get_directories_at(path): result+=script_text(path+"/"+name)
 return result

func labels() -> String:
 var result := ""
 for child in game.layer.get_children():
  if child is Label: result+=child.text+"\n"
 return result

func _initialize() -> void:
 _run.call_deferred()

func _run() -> void:
 var started: int=Time.get_ticks_msec()
 game=load("res://scenes/game.tscn").instantiate()
 root.add_child(game); await process_frame
 check(game.screen=="title","native entry is title")
 var supported: String=game.pixel_font.get_supported_chars()
 var visible: String=script_text("res://scripts")
 var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/registry.json"))
 for path in registry.files: visible+=FileAccess.get_file_as_string("res://data/"+str(path))
 var missing: String=""
 for ch in visible:
  if ch.unicode_at(0)>=0x4e00 and ch.unicode_at(0)<=0x9fff and not supported.contains(ch) and not missing.contains(ch): missing+=ch
 check(missing=="","imported runtime font covers all content/view Chinese glyphs: "+missing)
 game._new_game()
 check(game.journey.step=="opening","new game enters opening")
 for turn in range(240):
  if game.screen=="playbill" and game.journey.finished: break
  visited_steps.append(str(game.journey.act)+":"+str(game.journey.step))
  match str(game.journey.step):
   "opening","after_tutorial","curtain","dream","ending": game._next_page()
   "investigation":
    var inv: Dictionary=game.db.get_entry(game._act().investigation)
    for h in inv.hotspots:
     game._inspect(h)
     for line in h.lines: game._dialogue_next()
    check(game.journey.visited[inv.id].size()==inv.hotspots.size(),"all investigation hotspots visited "+inv.id)
    game._go("rehearsals")
   "rehearsals":
    var chosen := ""
    for id in game._act().rehearsals:
     if not id in game.journey.completed: chosen=id; break
    if chosen!="": game._start_rehearsal(chosen)
    else: game._go("curtain" if game.journey.act==1 else "fork")
   "rehearsal":
    var solutions: Array=Solver.solve(game.state.definition,game.journey)
    check(not solutions.is_empty(),"rehearsal solvable from UI")
    for command in solutions[0]: Duel.command(game.state,command)
    game._end_turn()
    check(game.state.outcome=="success","UI rehearsal completion "+game.rehearsal_id)
    var reward: int=game.journey.insight
    game._reset_rehearsal()
    for command in solutions[0]: Duel.command(game.state,command)
    game._end_turn()
    check(game.journey.insight==reward,"UI rehearsal reward is one-time")
    game._go("rehearsals")
   "fork": game._go("road")
   "road","duel":
    if game.state.outcome=="victory": game._victory()
    elif game.state.outcome=="defeat": check(false,"UI journey bot lost"); break
    else:
     # Exercise preview/cancel before the actual bot command.
     var saved_hash: int=hash(game.state)
     for command in Duel.legal_actions(game.state):
      if command.kind=="swap":
       game.preview=Duel.preview_swap(game.state,command.mode,command.a,command.b)
       game._cancel(); break
     check(hash(game.state)==saved_hash,"preview/cancel leaves rules unchanged")
     game._auto_turn()
   "letter": game._choose_letter(int(game.journey.act)-1)
   "shop":
    if game.journey.act==1: game._buy(game.db.get_entry("up.foresight"))
    elif game.journey.act==2: game._equip("mark.missing")
    game._depart()
  await process_frame
 check(game.journey.finished,"reached demo ending")
 game._resume()
 check(game.screen=="playbill" and not labels().contains("第 3 出"),"finished resume stays on clean playbill")
 check(game.journey.letters.size()==3,"all three letter choices saved")
 check(game.journey.completed.size()==8,"six rehearsals and two roads finite rewards")
 check(game.journey.marks.size()==2,"both marks acquired")
 check(game.journey.unlocked==3,"act four remains locked")
 var save:=Save.new()
 check(Journey.valid(save.restore()),"round-trip journey schema valid")
 game.journey.act=2; game._go("duel")
 while game.state.turn<3 and game.state.outcome=="": game._auto_turn()
 var known: Dictionary=game.journey.known_blanks.get("duel.thief",{}).duplicate(true)
 game.selected=0; game.target_action="marble"; game.preview={"stale":true}
 game._resume()
 check(game.preview.is_empty() and game.selected==-1 and game.target_action=="", "resume clears interrupted target and ghost selections")
 check(game.state.turn==1,"mid-duel resume restarts opening")
 check(game.state.filled.size()>=known.size(),"mid-duel resume remembers observed blanks")
 game._save()
 game.sounds.stop_all(); game.queue_free(); await process_frame
 game=load("res://scenes/game.tscn").instantiate(); root.add_child(game); await process_frame
 check(game._act().id=="act.2", "real disk reload normalizes JSON act to content id")
 game._resume()
 check(game.state.turn==1 and game.state.filled.size()>=known.size(), "fresh native scene resumes duel with observed blanks")
 game.selected=0; game.preview=Duel.preview_swap(game.state,"position",0,1); game.preview.a=0; game.preview.b=1
 game._render()
 var unchanged: int=hash(game.state)
 var right:=InputEventMouseButton.new(); right.button_index=MOUSE_BUTTON_RIGHT; right.pressed=true; right.position=Vector2(76,199)
 Input.parse_input_event(right); await process_frame
 check(game.preview.is_empty() and game.selected==-1 and hash(game.state)==unchanged,"right-click over slot cancels preview without rule mutation")
 game.journey.act=2; game._go("road"); game.state.turn=2; game.state.intents=preload("res://scripts/core/intents.gd").publish(game.state); game._render()
 check(labels().contains("守护2（自身）"),"guard intent UI identifies self effect")
 game.state.slots[2]=null; game._render()
 check(not labels().contains("环境"),"removed actor has no stale phantom intent")
 game.journey.upgrades["up.foresight"]=1; game.journey.act=3; game._start_rehearsal("reh.light")
 check(not labels().contains("下回合"),"one-turn rehearsal has no next-turn forecast")
 game.journey.act=2; game._go("duel")
 game.overlay="pause"; game._render(); game.overlay=""; game._render()
 check(game.state.turn==1,"pause close is non-mutating")
 # Corrupted saves are deliberately tested inside isolated QA HOME, never play data.
 var f:=FileAccess.open(Save.SAVE_PATH,FileAccess.WRITE); f.store_string("not json"); f.close()
 check(save.restore().is_empty(),"corrupt save returns safe empty result")
 check(not FileAccess.file_exists(Save.SAVE_PATH),"corrupt save quarantined")
 var report: Dictionary={"format":"d1-flow-smoke/1","checks":checks,"failures":failed,"visited_steps":visited_steps,"duration_ms":Time.get_ticks_msec()-started,"method":"Headless native scene callbacks + solver/bot; not a human full-playthrough duration or visual/audio acceptance."}
 f=FileAccess.open("res://../artifacts/reports/flow-d1.json",FileAccess.WRITE); f.store_string(JSON.stringify(report,"  ")+"\n"); f.close()
 game.sounds.stop_all(); game.queue_free(); await process_frame; await process_frame
 print("D1 full journey scene checks: ",checks," failures: ",failed)
 quit(1 if failed else 0)
