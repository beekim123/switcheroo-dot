extends Control
## D1 native graybox: five physical stage positions, never a card hand.
const DB = preload("res://scripts/content/content_db.gd")
const Stage = preload("res://scripts/core/stage_state.gd")
const Duel = preload("res://scripts/core/duel_rules.gd")
const Swap = preload("res://scripts/core/swap.gd")
const Sign = preload("res://scripts/core/signboard.gd")
const Rehearsal = preload("res://scripts/core/rehearsal.gd")
const Solver = preload("res://scripts/core/solver.gd")
const Bots = preload("res://scripts/core/bots.gd")
const Journey = preload("res://scripts/core/journey_state.gd")
const Save = preload("res://scripts/services/save_service.gd")
const Catalog = preload("res://scripts/services/asset_catalog.gd")
const Sounds = preload("res://scripts/services/audio_service.gd")
const Prologue = preload("res://scripts/core/rules/prologue.gd")
var db := DB.new()
var save := Save.new()
var catalog := Catalog.new()
var sounds := Sounds.new()
var journey: Dictionary={}
var state: Dictionary={}
var screen := "title"
var layer := Control.new()
var mode := "position"
var selected := -1
var target_action := ""
var preview: Dictionary={}
var notice := ""
var overlay := ""
var dialogue: Dictionary={}
var dialogue_index := 0
var rehearsal_id := ""
var failures: Dictionary={}
var pixel_font: FontFile
var cupper_texture: Texture2D
var keyboard_slot := 0
var automation := false
var auto_accumulator := 0.0
var debug_open := false
var elapsed := 0.0
var shot_mode := false

func _ready() -> void:
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 cupper_texture=catalog.texture("char.cupper")
 pixel_font=load("res://resources/fonts/fusion-pixel-12px/switcheroo-pixel-12.ttf")
 pixel_font.antialiasing=0; pixel_font.hinting=0; pixel_font.subpixel_positioning=0
 var t:=Theme.new(); t.default_font=pixel_font; t.default_font_size=12; theme=t
 add_child(sounds); sounds.setup(catalog)
 layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(layer)
 var saved: Dictionary=save.restore()
 if Journey.valid(saved): journey=Journey.normalize(saved.journey)
 elif not saved.is_empty(): save.quarantine(); notice="存档格式不完整，已安全备份。"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--act="):
   journey=Journey.fresh(); journey.act=clampi(int(arg.get_slice("=",1)),1,3); journey.unlocked=journey.act; journey.step="duel"; screen="journey"
  if arg=="--auto": automation=true
 if screen=="journey": _enter_step(false)
 _render()
 if "--shots" in OS.get_cmdline_user_args():
  shot_mode=true
  _capture_suite.call_deferred()

func _process(delta: float) -> void:
 if screen=="journey" and overlay=="": elapsed+=delta
 if automation and screen=="journey" and overlay=="" and not state.is_empty() and state.outcome=="":
  auto_accumulator+=delta
  if auto_accumulator>=0.3:
   auto_accumulator=0; _auto_turn()

func _save() -> void:
 if journey.is_empty() or shot_mode: return
 journey.elapsed_seconds=float(journey.get("elapsed_seconds",0))+elapsed; elapsed=0
 var result: Error=save.store({"journey":journey})
 if result!=OK: notice="存档暂时失败；仍可继续游戏。"

func _act() -> Dictionary:
 return db.get_entry("act."+str(int(journey.act)))

func _sound(id: String="sfx.cup_down") -> void:
 if not sounds.enabled: sounds.unlock()
 sounds.play(id)

func _clear() -> void:
 for child in layer.get_children(): layer.remove_child(child); child.queue_free()
 queue_redraw()

func _text(value: String, box: Rect2, color: String="#efe2c4", font_size: int=12, centered: bool=false) -> Label:
 var label:=Label.new(); label.text=value; label.position=box.position; label.size=box.size
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color(color))
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(label); label.size=box.size
 return label

func _button(value: String, box: Rect2, fn: Callable, disabled: bool=false, tooltip: String="") -> Button:
 var b:=Button.new(); b.text=value; b.position=box.position; b.add_theme_font_size_override("font_size",12)
 b.disabled=disabled; b.tooltip_text=tooltip
 for key in ["normal","hover","pressed","focus","disabled"]:
  var style:=StyleBoxFlat.new(); style.bg_color=Color("#7a1a2c" if key in ["hover","focus"] else "#292c45")
  style.border_color=Color("#665f66" if key=="disabled" else "#c99b58"); style.set_border_width_all(1)
  b.add_theme_stylebox_override(key,style)
 b.pressed.connect(func(): _sound(); fn.call())
 layer.add_child(b); b.size=box.size
 return b

func _render() -> void:
 _clear()
 if screen=="title": _title()
 elif screen=="playbill": _playbill()
 else:
  var act: Dictionary=_act()
  _text("第 "+str(journey.act)+" 出 · "+str(act.name),Rect2(28,14,430,24),"#fff0a8",18)
  _button("暂停",Rect2(558,12,58,24),func(): overlay="pause"; _render())
  match str(journey.step):
   "opening","after_tutorial","curtain","dream","ending": _story()
   "duel","road","rehearsal": _stage_ui()
   "investigation": _investigation()
   "rehearsals": _rehearsals()
   "fork": _fork()
   "letter": _letter()
   "shop": _shop()
   "playbill": screen="playbill"; _playbill()
 if not notice.is_empty() and state.is_empty(): _text(notice,Rect2(32,324,576,24),"#eec05a")
 if overlay!="": _overlay()
 if debug_open: _debug()

func _title() -> void:
 _text("掉包记",Rect2(170,62,300,48),"#fff0a8",36,true)
 _text("一个交换，五个站位，三出好戏。",Rect2(120,122,400,24),"#eec05a",12,true)
 _text("麦朵被换到了远方。\n带上杯戏师，顺着戏台找回她。",Rect2(140,168,360,48),"#efe2c4",12,true)
 _button("进戏场",Rect2(240,250,160,32),func(): screen="playbill"; _render())
 _text("D1 规则灰盒 · 鼠标操作 / Esc 暂停",Rect2(140,300,360,24),"#aaa7b0",12,true)

func _playbill() -> void:
 _text("今夜戏单",Rect2(32,28,280,36),"#fff0a8",24)
 _button("继续旅程",Rect2(400,28,190,32),_resume,journey.is_empty())
 for i in range(1,4):
  var act: Dictionary=db.get_entry("act."+str(i))
  var unlocked: bool=i<=int(journey.get("unlocked",1))
  _button(str(i)+" · "+str(act.name),Rect2(36,90+(i-1)*52,340,40),_select_act.bind(i),not unlocked)
 _text("第四出 · 钟塔镇\n下回分解",Rect2(414,112,180,72),"#8a8799",18,true)
 _button("重新开场",Rect2(36,274,160,32),func():
  if journey.is_empty(): _new_game()
  else: overlay="new"; _render())
 _button("回到标题",Rect2(436,274,160,32),func(): screen="title"; _render())

func _new_game() -> void:
 journey=Journey.fresh(); overlay=""; screen="journey"; _enter_step()

func _select_act(number: int) -> void:
 if journey.is_empty(): journey=Journey.fresh()
 journey.act=number; journey.step="opening"; journey.story_index=0; screen="journey"; _enter_step()

func _resume() -> void:
 if journey.is_empty(): return
 screen="playbill" if journey.step=="playbill" else "journey"; _enter_step(false)

func _go(step: String) -> void:
 journey.step=step; journey.story_index=0; selected=-1; preview={}; target_action=""; notice=""; _enter_step()

func _enter_step(store: bool=true) -> void:
 state={}; dialogue={}; mode="position"; selected=-1; preview={}; target_action=""; notice=""
 var act: Dictionary=_act()
 match str(journey.step):
  "duel","road":
   var def: Dictionary=db.get_entry(act.duel if journey.step=="duel" else act.road)
   state=Duel.start(def,journey)
   if "--fill=all" in OS.get_cmdline_user_args():
    for key in state.signboard.get("blanks",{}): Sign.fill(state,key,"debug")
  "rehearsal":
   rehearsal_id=str(journey.get("rehearsal_id",act.rehearsals[0]))
   state=Rehearsal.start(db.get_entry(rehearsal_id),journey); mode=state.definition.mode
  "ending": journey.finished=true
 if store: _save()
 _render()

func _story_pages() -> Array:
 return db.all("ending") if journey.step=="ending" else _act().get(journey.step,[])

func _story() -> void:
 var pages: Array=_story_pages()
 var index: int=int(journey.story_index)
 if index>=pages.size(): _story_done(); return
 var page: Dictionary=pages[index]
 var dream: bool=journey.step=="dream"
 _text("梦里" if dream else ("谢幕" if journey.step=="curtain" else "葛伦讲古"),Rect2(60,66,490,30),"#9cb6cc" if dream else "#eec05a",18)
 _text(str(page.speaker),Rect2(74,120,490,24),"#eec05a")
 _text(str(page.text),Rect2(74,156,490,94),"#efe2c4",18)
 _text(str(index+1)+" / "+str(pages.size())+" · 文字灰盒",Rect2(60,292,240,24),"#aaa7b0")
 _button("下一页",Rect2(442,286,132,32),_next_page)
 _button("跳过",Rect2(462,64,108,24),_story_done)

func _next_page() -> void:
 journey.story_index+=1
 if journey.story_index>=_story_pages().size(): _story_done()
 else: _save(); _render()

func _story_done() -> void:
 match str(journey.step):
  "opening": _go("duel" if journey.act==1 else "investigation")
  "after_tutorial": _go("investigation")
  "curtain": _go("letter")
  "dream": _go("shop")
  "ending": screen="playbill"; journey.step="playbill"; _save(); _render()

func _investigation() -> void:
 var inv: Dictionary=db.get_entry(_act().investigation)
 var seen: Array=journey.visited.get(inv.id,[])
 _text("幕前查访 · "+inv.name,Rect2(34,54,390,24),"#eec05a")
 for i in range(inv.hotspots.size()):
  var h: Dictionary=inv.hotspots[i]
  var x: int=42+(i%3)*190; var y: int=98+(i/3)*70
  _button(("已问 · " if h.id in seen else "？ ")+str(h.name),Rect2(x,y,172,44),_inspect.bind(h))
 _text("还有 "+str(inv.hotspots.size()-seen.size())+" 处没看",Rect2(36,246,300,24),"#aaa7b0")
 _button("手账",Rect2(366,282,90,30),func(): overlay="journal"; _render())
 _button("去找他",Rect2(470,282,130,30),func():
  if seen.size()<inv.hotspots.size(): overlay="leave"; _render()
  else: _go("rehearsals"))
 if not dialogue.is_empty():
  _panel(Rect2(28,220,584,126))
  _text(str(dialogue.name)+"："+str(dialogue.lines[dialogue_index]),Rect2(42,232,554,64),"#efe2c4",12)
  _button("继续",Rect2(486,306,108,28),_dialogue_next)

func _inspect(hotspot: Dictionary) -> void:
 dialogue=hotspot; dialogue_index=0; _render()

func _dialogue_next() -> void:
 dialogue_index+=1
 if dialogue_index>=dialogue.lines.size():
  var id: String=_act().investigation
  if not journey.visited.has(id): journey.visited[id]=[]
  if not dialogue.id in journey.visited[id]: journey.visited[id].append(dialogue.id)
  if dialogue.get("clue")!=null and not dialogue.clue in journey.clues:
   journey.clues.append(dialogue.clue); notice="拿到词签。开幕时会填进水牌。"
  if dialogue.get("motive")!=null and not dialogue.motive in journey.motives: journey.motives.append(dialogue.motive)
  dialogue={}; _save()
 _render()

func _rehearsals() -> void:
 _text("排练 · 一回合的小戏法",Rect2(40,66,560,30),"#eec05a",18)
 for i in range(2):
  var r: Dictionary=db.get_entry(_act().rehearsals[i])
  _text(r.goal,Rect2(58,142+i*66,430,28))
  _button(str(r.name)+( " · 已完成" if r.id in journey.completed else " · 领悟 +1"),Rect2(48,108+i*66,536,32),_start_rehearsal.bind(r.id))
 _button("继续赶路",Rect2(424,276,160,32),func(): _go("curtain" if journey.act==1 else "fork"))
 _text("完成过的排练可以重玩，但不会重复得领悟。",Rect2(48,318,536,24),"#aaa7b0")

func _start_rehearsal(id: String) -> void:
 journey.rehearsal_id=id; _go("rehearsal")

func _fork() -> void:
 _text("一条大路，一条小路。",Rect2(60,92,520,32),"#eec05a",24,true)
 _text("大路有场小麻烦，过了多一点领悟。\n抄小路，就直接去找这出戏的对手。",Rect2(90,158,460,64),"#efe2c4",18,true)
 _button("走大路 · 领悟 +1",Rect2(62,260,246,40),func(): _go("road"))
 _button("抄小路 · 去对戏",Rect2(330,260,246,40),func(): _go("duel"))

func _letter() -> void:
 var letter: Dictionary=_act().letter
 _text("写给麦朵",Rect2(50,62,520,30),"#eec05a",24)
 _text(str(letter.body),Rect2(62,110,520,92),"#efe2c4",18)
 for i in range(3):
  _button(str(letter.choices[i]),Rect2(62,220+i*36,516,30),_choose_letter.bind(i))

func _choose_letter(index: int) -> void:
 journey.letters[str(int(journey.act))]={"index":index,"text":_act().letter.choices[index]}; _go("dream")

func _shop() -> void:
 _text("葛伦的铺子 · 领悟 "+str(journey.insight),Rect2(32,54,576,30),"#eec05a",18)
 var upgrades: Array=db.all("upgrades")
 for i in range(upgrades.size()):
  var u: Dictionary=upgrades[i]
  var n: int=int(journey.upgrades.get(u.id,0))
  _button(str(u.name)+"  "+str(int(u.cost))+" 点  "+str(n)+"/"+str(int(u.limit)),Rect2(34,94+i*44,248,32),_buy.bind(u),n>=int(u.limit) or int(journey.insight)<int(u.cost))
  _text(str(u.description),Rect2(292,101+i*44,314,24))
 _text("印记只装一枚：",Rect2(34,278,144,24),"#aaa7b0")
 var marks: Array=[""]+journey.marks
 for i in range(marks.size()):
  var id: String=marks[i]
  var mark: Dictionary=db.get_entry(id)
  _button(("已装 " if journey.mark==id else "")+("不装" if id=="" else str(mark.name)),Rect2(178+i*100,274,94,28),_equip.bind(id))
 _button("出发" if journey.act<3 else "等一封回信",Rect2(444,316,160,30),_depart)

func _buy(upgrade: Dictionary) -> void:
 if Journey.buy(journey,upgrade): _save()
 _render()

func _equip(id: String) -> void:
 journey.mark=id; _save(); _render()

func _depart() -> void:
 if journey.act<3:
  journey.act+=1; journey.unlocked=maxi(journey.unlocked,journey.act); _go("opening")
 else: _go("ending")

func _stage_ui() -> void:
 var shown: Dictionary=preview.get("state",state)
 var danger: Dictionary=Duel.threats(shown)
 var is_rehearsal: bool=journey.step=="rehearsal"
 _text(("排练 · "+str(state.definition.name)+"："+str(state.definition.goal)) if is_rehearsal else str(state.definition.name)+" · 第 "+str(state.turn)+" 回合",Rect2(28,42,578,22),"#eec05a")
 var intent_names: Dictionary={"hit":"打","pole":"撑篙","touch":"摸","extinguish":"吹灭","move":"移动","roll":"滚","swap":"交换","guard":"守护","rain":"漏雨","steal":"抢","check":"检查"}
 for i in range(shown.intents.size()):
  var intent: Dictionary=shown.intents[i]
  var e: Dictionary=Stage.entity(shown,str(intent.actor))
  if e.is_empty() and intent.actor not in ["environment","cupper"]: continue
  var actor_name: String=e.get("name","杯戏师" if intent.actor=="cupper" else "环境")
  var suffix: String=" → 槽 "+str(int(intent.get("slot",0))+1)
  if intent.kind=="guard": suffix="（自身）"
  if intent.kind=="swap": suffix=" 槽 "+str(int(intent.a)+1)+" ↔ "+str(int(intent.b)+1)
  var stun: String=" [晕]" if int(e.get("stun",0))>0 else ""
  if intent.kind!="guard" and int(intent.get("slot",-1))>=0:
   _text(str(i+1),Rect2(61+int(intent.slot)*90+i*10,111,18,16),"#ef8874",12,true)
  _text(str(i+1)+" "+actor_name+" · "+str(intent_names.get(intent.kind,intent.kind))+(str(int(intent.get("amount",0))) if int(intent.get("amount",0))>0 else "")+suffix+stun,Rect2(32,68+i*17,462,18),"#aaa7b0" if stun!="" else "#efe2c4")
 for i in range(5):
  var e: Variant=shown.slots[i]
  var x: int=34+i*90
  _text("将受 "+str(danger.slots[i]),Rect2(x,128,84,18),"#ef8874" if int(danger.slots[i])>0 else "#aaa7b0",12,true)
  if e!=null:
   _text(str(e.name)+( "·隐" if Stage.hidden(shown,i) else ""),Rect2(x-2,150,88,20),"#aaa7b0" if Stage.hidden(shown,i) else "#fff0a8",12,true)
   var hp: String="不坏" if e.unbreakable else str(int(e.hp))+"/"+str(int(e.max_hp))
   if target_action!="" and Duel.can_main(state,target_action,i):
    var mp: Dictionary=Duel.preview_main(state,target_action,i)
    var target: Dictionary=Stage.entity(mp.state,e.id)
    hp=str(int(e.hp))+"→"+str(int(target.get("hp",0)))
   _text(hp+(" 护"+str(int(e.guard)) if int(e.guard)>0 else ""),Rect2(x,222,84,18),"#efe2c4",12,true)
   if e.item!="": _text(_held_name(e.item),Rect2(x,204,84,18),"#eec05a",12,true)
   if "hand" in e.marks: _text("手印",Rect2(x+50,174,36,18),"#ef8874")
  _text(str(i+1),Rect2(x,241,84,18),"#c99b58",12,true)
  var hit:=Button.new(); hit.flat=true; hit.position=Vector2(x,146); hit.size=Vector2(84,111)
  for key in ["normal","hover","pressed","focus"]: hit.add_theme_stylebox_override(key,StyleBoxEmpty.new())
  hit.pressed.connect(_slot.bind(i)); hit.tooltip_text=_slot_tip(i); layer.add_child(hit)
 _text(("一回合内完成目标。
免费无限重试。" if is_rehearsal else Sign.sentence(state)),Rect2(506,112,106,122),"#fff0a8" if state.exposed else "#c99b58")
 _text("排练中" if is_rehearsal else "识破" if state.exposed else "水牌",Rect2(510,80,94,24),"#ef8874" if state.exposed else "#c99b58",18,true)
 if not preview.is_empty():
  _text("反转！" if preview.reversal else "交换预览 · 尚未执行",Rect2(32,264,270,22),"#fff0a8")
  _button("确认交换",Rect2(400,262,108,26),_confirm_swap)
  _button("取消",Rect2(520,262,84,26),_cancel)
 else:
  var p: int=Stage.player_slot(state)
  _text("生命 "+str(Stage.player_hp(state))+"  守护 "+str(int(state.slots[p].guard) if p>=0 else 0)+"  本回合将受 "+str(danger.player),Rect2(28,264,570,22),"#ef8874" if danger.player>0 else "#efe2c4")
 if is_rehearsal:
  _button("换位" if mode=="position" else "换物",Rect2(28,294,88,28),func(): target_action=""; _render(),int(state.swap_used)>=int(state.swap_limit))
  _button("开演",Rect2(412,294,88,28),_end_turn,state.outcome!="")
  _button("重置",Rect2(512,294,88,28),_reset_rehearsal)
  _button("回排练",Rect2(128,294,88,28),func(): _go("rehearsals"))
 else:
  var strike_available := false
  for i in range(5):
   if Duel.can_main(state,"strike",i): strike_available=true
  _button("出手",Rect2(28,294,64,28),_choose_action.bind("strike"),not strike_available)
  _button("架势",Rect2(98,294,64,28),_main.bind("guard",-1),not Duel.can_main(state,"guard"))
  _button("糖 "+str(int(state.items.get("item.candied_haw",0))),Rect2(168,294,64,28),_main.bind("heal",-1),not Duel.can_main(state,"heal"))
  _button("弹珠 "+str(int(state.items.get("item.marble",0))),Rect2(238,294,74,28),_choose_action.bind("marble"),state.main_used or int(state.items.get("item.marble",0))<=0)
  if not (state.rule=="prologue" and state.turn==1):
   _button("换位",Rect2(320,294,64,28),_mode.bind("position"),state.swap_used>=state.swap_limit)
   if state.item_unlocked: _button("换物",Rect2(390,294,64,28),_mode.bind("item"),state.swap_used>=state.swap_limit)
  _button("结束",Rect2(512,294,88,28),_end_turn,state.outcome!="")
 var help: String=notice
 if help=="":
  if state.rule=="prologue": help=Prologue.tutorial(state.turn)
  elif target_action!="": help="选择目标："+("相邻出手，造成 "+str(state.strike)+" 点" if target_action=="strike" else "弹珠，造成 2 点")
  elif state.exposed and not state.reversal_used: help="！ "+str(state.definition.get("reversal",{}).get("description",""))
  else: help="点两个站位预览"+ ("换物" if mode=="item" else "换位")+"；右键取消。每回合一次主行动 + 一次交换。"
 _text(help,Rect2(28,328,580,28),"#eec05a")
 if state.foresight and journey.step!="rehearsal":
  var future: Dictionary=state.duplicate(true); future.turn+=1
  var intents: Array=preload("res://scripts/core/intents.gd").publish(future)
  _text("下回合："+str(intent_names.get(intents[0].kind,intents[0].kind)) if not intents.is_empty() else "",Rect2(504,244,114,32),"#aaa7b0")
 if state.outcome!="": _result()

func _held_name(id: String) -> String:
 return {"held.stone":"持：石子","held.empty_lamp":"持：空灯","held.borrowed_lantern":"持：借光灯","held.bright_lantern":"持：亮灯","held.key":"持：钥匙"}.get(id,id)

func _slot_tip(slot: int) -> String:
 if selected>=0: return str(Swap.can(state,mode,selected,slot).reason)
 if Stage.hidden(state,slot): return "看不见他"
 if state.slots[slot]!=null and state.slots[slot].heavy and mode=="position": return "太重了，换不动"
 return "槽 "+str(slot+1)

func _mode(value: String) -> void:
 if not state.is_empty() and state.get("rehearsal",false): value=state.definition.mode
 mode=value; target_action=""; selected=-1; preview={}; notice=""; _render()

func _choose_action(value: String) -> void:
 selected=-1; preview={}; target_action=value; notice=""; _render()

func _slot(slot: int) -> void:
 if state.outcome!="" or overlay!="": return
 _sound()
 if target_action!="": _main(target_action,slot); return
 if not preview.is_empty():
  if slot==int(preview.get("b",-1)): _confirm_swap()
  else: _cancel()
  return
 if selected<0:
  if Stage.hidden(state,slot): Sign.observe(state,"first_hidden"); notice="看不见他"; _remember(); _render(); return
  if mode=="position" and state.slots[slot]!=null and state.slots[slot].heavy: notice="太重了，换不动"; _render(); return
  selected=slot; notice="选第二个站位；按右键可以取消。"
 else:
  var result: Dictionary=Duel.preview_swap(state,mode,selected,slot)
  if result.ok: preview=result; preview.a=selected; preview.b=slot; notice=""
  else: notice=result.reason
 _render()

func _confirm_swap() -> void:
 if preview.is_empty(): return
 var events: Array=Duel.swap(state,mode,int(preview.a),int(preview.b))
 preview={}; selected=-1; _events(events); _remember(); _sound("sfx.cup_up"); _render()

func _main(kind: String, slot: int) -> void:
 var events: Array=Duel.main_action(state,kind,slot)
 if events.is_empty(): notice="这个目标现在不能选。"
 else: target_action=""; _events(events)
 _remember(); _render()

func _end_turn() -> void:
 preview={}; selected=-1; target_action=""
 if journey.step=="rehearsal":
  if Rehearsal.perform(state): Journey.reward(journey,rehearsal_id); _save()
  else: failures[rehearsal_id]=int(failures.get(rehearsal_id,0))+1
 else:
  _events(Duel.end_turn(state)); _remember()
 _render()

func _events(events: Array) -> void:
 notice=""
 for event in events:
  if event.type=="self_hit": notice="噗——它打到了自己！"
  if event.type=="blank_filled": notice="原来是这样：水牌填上了一个字。"
  if event.type=="exposed": notice="识破！杯戏师朝反转目标比划。"; _sound("sting.exposed")
  if event.type=="reversal": notice="反转！"+str(state.definition.get("reversal",{}).get("name","")); _sound("sting.exposed")

func _remember() -> void:
 Journey.remember(journey,state); _save()

func _result() -> void:
 _panel(Rect2(132,100,376,158))
 var title: String={"victory":"这出戏，赢了！","defeat":"别怕，再来一出。","success":"排练成功 · 领悟 +1","retry":"没关系，再试一次。"}.get(state.outcome,"")
 if state.outcome=="success" and rehearsal_id in journey.completed: title="排练成功 · 已记入领悟"
 _text(title,Rect2(148,120,344,34),"#fff0a8",18,true)
 if state.outcome=="victory": _button("谢幕",Rect2(226,196,188,32),_victory)
 elif state.outcome=="defeat":
  _button("再来一出",Rect2(154,168,156,30),func(): _enter_step())
  _button("援助",Rect2(330,168,156,30),func(): overlay="pause"; _render())
  if journey.step=="road": _button("绕开",Rect2(226,210,188,30),func(): _go("duel"))
 elif state.outcome=="success": _button("回排练",Rect2(226,196,188,32),func(): _go("rehearsals"))
 else:
  _button("免费重试",Rect2(154,196,156,32),_reset_rehearsal)
  if int(failures.get(rehearsal_id,0))>=2: _button("杯戏师提示",Rect2(326,196,164,32),_hint)

func _reset_rehearsal() -> void:
 selected=-1; preview={}; notice=""; _enter_step(false)

func _hint() -> void:
 if journey.step=="rehearsal":
  var solutions: Array=Solver.solve(state.definition,journey)
  if not solutions.is_empty():
   _reset_rehearsal()
   for command in solutions[0]: Duel.command(state,command)
   notice="杯戏师比划了一次交换；点开演看看。"
 else:
  var plan: Array=Bots.choose(state)
  for command in plan:
   if command.kind=="swap":
    selected=int(command.a); preview=Duel.preview_swap(state,command.mode,command.a,command.b); preview.a=command.a; preview.b=command.b; mode=command.mode; break
 _render()

func _victory() -> void:
 if journey.step=="road": Journey.reward(journey,state.id); _go("duel"); return
 var reward: String=state.definition.get("reward_mark","")
 if reward!="" and not reward in journey.marks: journey.marks.append(reward)
 _go("after_tutorial" if journey.act==1 else "curtain")

func _cancel() -> void:
 selected=-1; preview={}; target_action=""; notice="已取消。"; _render()

func _panel(box: Rect2) -> void:
 var bg:=ColorRect.new(); bg.color=Color("#171827"); bg.position=box.position; bg.size=box.size; layer.add_child(bg)

func _overlay() -> void:
 var cover:=ColorRect.new(); cover.color=Color(0,0,0,0.45); cover.size=Vector2(640,360); layer.add_child(cover)
 _panel(Rect2(78,48,484,268))
 if overlay=="pause":
  _text("歇一歇",Rect2(108,68,400,30),"#fff0a8",24)
  _button("继续",Rect2(108,112,192,30),func(): overlay=""; _render())
  _button("回戏单",Rect2(320,112,212,30),func(): _save(); overlay=""; screen="playbill"; state={}; _render())
  _button("提示："+("开" if journey.hint else "关"),Rect2(108,160,192,30),func(): journey.hint=not journey.hint; _save(); _render())
  _button("让一让："+("开" if journey.assist else "关"),Rect2(320,160,212,30),func(): journey.assist=not journey.assist; _save(); _render())
  _text("让一让：重来时对手生命减少三成。\n提示不会替你确认交换。已填空格保留。",Rect2(108,204,424,62))
  if not state.is_empty() and journey.hint: _button("看看推荐交换",Rect2(108,270,424,30),func(): overlay=""; _hint())
 elif overlay=="journal":
  _text("手账 · 已收集词签 "+str(journey.clues.size()),Rect2(108,68,424,30),"#fff0a8",18)
  var words: Array=[]
  for clue in journey.clues:
   for duel in db.all("duels"):
    for blank in duel.get("signboard",{}).get("blanks",{}).values():
     if blank.clue==clue: words.append(blank.word)
  _text("词签："+"、".join(words)+"\n\n线索："+"\n".join(journey.motives),Rect2(108,112,424,146))
  _button("合上",Rect2(344,270,188,30),func(): overlay=""; _render())
 else:
  _text("还有没看过的地方，确定离开？" if overlay=="leave" else "重新开场会覆盖这份旅程。确定吗？",Rect2(108,104,424,88),"#fff0a8",18)
  _button("取消",Rect2(108,238,192,32),func(): overlay=""; _render())
  _button("确定",Rect2(320,238,212,32),func():
   var old: String=overlay; overlay=""
   if old=="leave": _go("rehearsals")
   else: _new_game())

func _debug() -> void:
 _panel(Rect2(72,48,496,228))
 _text("调试 · F1 关闭",Rect2(94,60,420,28),"#eec05a",18)
 for act in range(1,4): _button("第 "+str(act)+" 出对戏",Rect2(90+(act-1)*152,104,144,32),_debug_duel.bind(act))
 _button("填满水牌",Rect2(90,154,144,32),func():
  if not state.is_empty():
   for key in state.signboard.get("blanks",{}): Sign.fill(state,key,"debug")
  debug_open=false; _render())
 _button("自动操作："+("开" if automation else "关"),Rect2(244,154,220,32),func(): automation=not automation; debug_open=false; _render())
 _button("领悟 +1",Rect2(90,204,144,32),func():
  if journey.is_empty(): journey=Journey.fresh()
  journey.insight+=1; _render())

func _debug_duel(act: int) -> void:
 if journey.is_empty(): journey=Journey.fresh()
 journey.act=act; journey.unlocked=maxi(journey.unlocked,act); screen="journey"; debug_open=false; _go("duel")

func _auto_turn() -> void:
 var plan: Array=Bots.choose(state)
 for command in plan: Duel.command(state,command)
 if state.outcome=="": Duel.end_turn(state)
 _remember(); _render()

func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and screen=="journey" and not state.is_empty() and overlay=="":
  _cancel()
  get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  if not state.is_empty(): _cancel()
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode==KEY_F1: debug_open=not debug_open; _render(); return
 if event.keycode==KEY_ESCAPE:
  if selected>=0 or not preview.is_empty() or target_action!="": _cancel()
  elif overlay!="": overlay=""; _render()
  elif screen=="journey": overlay="pause"; _render()
  return
 if overlay!="": return
 if screen=="journey" and journey.step in ["opening","after_tutorial","curtain","dream","ending"] and event.keycode in [KEY_SPACE,KEY_ENTER]: _next_page(); return
 if state.is_empty() or state.outcome!="": return
 match event.keycode:
  KEY_A: _choose_action("strike")
  KEY_G: _main("guard",-1)
  KEY_I: _choose_action("marble")
  KEY_E: _end_turn()
  KEY_TAB: _mode("item" if mode=="position" and state.item_unlocked else "position")
  KEY_LEFT: keyboard_slot=maxi(0,keyboard_slot-1); queue_redraw()
  KEY_RIGHT: keyboard_slot=mini(4,keyboard_slot+1); queue_redraw()
  KEY_ENTER: _slot(keyboard_slot)

func _draw() -> void:
 draw_rect(Rect2(0,0,640,360),Color("#171827"))
 draw_rect(Rect2(0,0,640,8),Color("#7a1a2c"))
 for x in range(0,640,32): draw_rect(Rect2(x,8,24,4),Color("#4a0f1e"))
 draw_rect(Rect2(12,12,8,248),Color("#4a0f1e")); draw_rect(Rect2(620,12,8,248),Color("#4a0f1e"))
 if not state.is_empty() and screen=="journey":
  var shown: Dictionary=preview.get("state",state)
  draw_rect(Rect2(28,238,462,20),Color("#59402d")); draw_rect(Rect2(28,258,584,2),Color("#c99b58"))
  draw_rect(Rect2(500,72,118,170),Color("#30262b")); draw_rect(Rect2(500,72,118,170),Color("#8b6b46"),false,2)
  for i in range(5):
   var x: int=34+i*90
   var lit: bool=Stage.is_lit(shown,i)
   draw_rect(Rect2(x,174,84,64),Color("#39302b" if lit and shown.light_rules else "#22233a"))
   draw_rect(Rect2(x,238,84,2),Color("#eec05a" if lit and shown.light_rules else "#8b6b46"))
   if target_action!="" and Duel.can_main(state,target_action,i): draw_rect(Rect2(x,146,84,111),Color("#ef8874"),false,1)
   elif selected>=0 and Swap.can(state,mode,selected,i).ok: draw_rect(Rect2(x,146,84,111),Color("#c99b58"),false,1)
   if selected==i: draw_rect(Rect2(x,146,84,111),Color("#fff0a8"),false,2)
   if keyboard_slot==i: draw_line(Vector2(x+35,256),Vector2(x+49,256),Color("#eec05a"),2)
   var e: Variant=shown.slots[i]
   if e==null: continue
   var c:=Color("#6e8b9b" if e.kind=="player" else "#ba6d6e" if e.kind=="rival" else "#9d936c" if e.kind=="prop" else "#9a88b4")
   if Stage.hidden(shown,i): c=Color("#444151")
   if not preview.is_empty(): c.a=0.60
   var center:=Vector2(x+42,198)
   if e.kind in ["player","rival"]:
    draw_rect(Rect2(center.x-11,center.y-23,22,16),c)
    draw_rect(Rect2(center.x-15,center.y-7,30,22),c)
    draw_rect(Rect2(center.x-13,center.y+15,10,7),c); draw_rect(Rect2(center.x+3,center.y+15,10,7),c)
    draw_rect(Rect2(center.x-5,center.y-18,3,3),Color("#171827")); draw_rect(Rect2(center.x+4,center.y-18,3,3),Color("#171827"))
    if e.kind=="player": draw_rect(Rect2(center.x-15,center.y-7,31,5),Color("#d98b48"))
   elif e.get("archetype","")=="prop.lamp_post" or str(e.id).contains("lamp"):
    draw_rect(Rect2(center.x-2,center.y-14,4,34),Color("#8b6b46")); draw_rect(Rect2(center.x-12,center.y-22,24,16),Color("#eec05a" if e.lit else "#665f66"))
   elif e.kind=="foe":
    draw_rect(Rect2(center.x-16,center.y-10,32,24),c); draw_rect(Rect2(center.x-9,center.y-18,18,8),c)
    draw_rect(Rect2(center.x-8,center.y-6,4,4),Color("#171827")); draw_rect(Rect2(center.x+5,center.y-6,4,4),Color("#171827"))
   else:
    draw_rect(Rect2(center.x-22,center.y-12,44,32),c); draw_rect(Rect2(center.x-22,center.y-12,44,32),Color("#66503d"),false,2)
    draw_line(Vector2(center.x-18,center.y-7),Vector2(center.x+18,center.y+15),Color("#66503d"),2)
   if e.kind=="player":
    var tex: Texture2D=cupper_texture
    draw_texture_rect_region(tex,Rect2(x+2,178,24,32),Rect2(0,0,24,32),Color(1,1,1,0.65) if not preview.is_empty() else Color.WHITE)
  for n in range(shown.intents.size()):
   var intent: Dictionary=shown.intents[n]
   if intent.kind=="guard": continue
   var start_slot: int=Stage.slot_of(shown,str(intent.actor))
   if start_slot<0 and intent.actor not in ["environment","cupper"]: continue
   var end_slot: int=int(intent.get("slot",0))
   if end_slot<0 or end_slot>4: continue
   var start:=Vector2(76+maxi(0,start_slot)*90,123-n*4)
   var end:=Vector2(76+end_slot*90,146)
   draw_line(start,Vector2(end.x,start.y),Color("#cf7766"),1)
   draw_line(Vector2(end.x,start.y),end,Color("#cf7766"),1)
   draw_line(end,Vector2(end.x-3,end.y-4),Color("#cf7766"),1); draw_line(end,Vector2(end.x+3,end.y-4),Color("#cf7766"),1)
 else:
  for x in range(50,600,30): draw_rect(Rect2(x,348,12,4),Color("#c99b58"))
  draw_circle(Vector2(522,56),18,Color("#c99b58")); draw_circle(Vector2(555,76),10,Color("#9cb6cc"))


func _capture(name: String) -> void:
 _render()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var picture: Image=get_viewport().get_texture().get_image()
 var destination: String=ProjectSettings.globalize_path("res://../artifacts/screenshots/")
 picture.save_png(destination+"d1-"+name+"-1x.png")
 picture.resize(1920,1080,Image.INTERPOLATE_NEAREST)
 picture.save_png(destination+"d1-"+name+"-3x.png")
 print("D1 capture: ",name)

func _capture_suite() -> void:
 screen="title"; state={}; overlay=""; notice=""
 await _capture("title")
 journey=Journey.fresh(); journey.unlocked=3; screen="playbill"
 await _capture("playbill")
 screen="journey"; journey.act=2; journey.step="investigation"; _enter_step(false)
 await _capture("investigation")
 journey.act=1; journey.rehearsal_id="reh.geese"; journey.step="rehearsal"; _enter_step(false)
 await _capture("rehearsal")
 journey.act=2; journey.step="duel"; _enter_step(false)
 await _capture("thief")
 selected=0; preview=Duel.preview_swap(state,"position",0,1); preview.a=0; preview.b=1
 await _capture("swap-preview")
 selected=-1; preview={}
 while not state.exposed and state.outcome=="" and state.turn<8: _auto_turn()
 await _capture("exposed")
 for action in Duel.legal_actions(state):
  if action.kind!="swap": continue
  var pv: Dictionary=Duel.preview_swap(state,action.mode,action.a,action.b)
  if pv.ok and pv.reversal:
   mode=action.mode; selected=action.a; preview=pv; preview.a=action.a; preview.b=action.b; break
 await _capture("reversal-preview")
 if not preview.is_empty(): _confirm_swap()
 await _capture("reversal")
 journey.act=3; journey.step="duel"; _enter_step(false)
 await _capture("ferryman-dark")
 journey.step="letter"; state={}
 await _capture("letter")
 journey.step="shop"; journey.insight=5; journey.marks=["mark.missing","mark.glow"]
 await _capture("shop")
 journey.step="ending"; journey.story_index=1
 await _capture("ending")
 sounds.stop_all()
 await get_tree().process_frame
 get_tree().quit()
