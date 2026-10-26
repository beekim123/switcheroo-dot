extends RefCounted
const Stage = preload("res://scripts/core/stage_state.gd")
const Duel = preload("res://scripts/core/duel_rules.gd")

static func choose(s: Dictionary, strategy: String="lookahead") -> Array:
 var candidates: Array=[[]]
 var first: Array=Duel.legal_actions(s)
 for a in first:
  if not _allowed(s,a,strategy): continue
  candidates.append([a])
  var copy: Dictionary=s.duplicate(true)
  Duel.command(copy,a)
  if copy.outcome!="": continue
  for b in Duel.legal_actions(copy):
   if (a.kind=="swap")== (b.kind=="swap") or not _allowed(copy,b,strategy): continue
   candidates.append([a,b])
 var best: Array=[]
 var score: float=-INF
 for plan in candidates:
  var copy: Dictionary=s.duplicate(true)
  for action in plan:
   Duel.command(copy,action)
   if copy.outcome!="": break
  if copy.outcome=="": Duel.end_turn(copy)
  var value: float=_score(s,copy,strategy)
  if value>score:
   score=value; best=plan
 return best

static func _allowed(s: Dictionary, action: Dictionary, strategy: String) -> bool:
 if action.kind!="swap": return true
 if strategy=="no_swap": return false
 if strategy=="cautious":
  if action.mode!="position": return false
  var p: int=Stage.player_slot(s)
  if not (p in [int(action.a),int(action.b)]): return false
  var before: Dictionary=Duel.threats(s)
  if before.player<=0: return false
  var preview: Dictionary=Duel.preview_swap(s,action.mode,action.a,action.b)
  return preview.ok and int(preview.threats.player)<int(before.player)
 return true

static func _score(before: Dictionary, after: Dictionary, strategy: String) -> float:
 if after.outcome=="defeat": return -100000.0
 if after.outcome=="victory": return 100000.0+Stage.player_hp(after)
 var value: float=float(Stage.enemy_hp(before)-Stage.enemy_hp(after))*6.0
 value+=float(Stage.player_hp(after)-Stage.player_hp(before))*3.0
 value+=float(after.items.get("item.candied_haw",0))*2.0+float(after.items.get("item.marble",0))*0.8
 var p: int=Stage.player_slot(after)
 if p>=0:
  var nearest := 5
  for i in range(5):
   if after.slots[i]!=null and after.slots[i].kind in ["foe","rival"] and not Stage.hidden(after,i): nearest=mini(nearest,absi(i-p))
  value-=float(nearest)*1.5
 if strategy=="lookahead":
  value+=float(after.filled.size()-before.filled.size())*15.0
  if after.exposed and not before.exposed: value+=16.0
  if after.reversal_used and not before.reversal_used: value+=60.0
  if after.exposed and not after.reversal_used:
   # A visible two-step setup is worth more than a blind damaging swap.
   if after.rule=="thief":
    var basket:=Stage.slot_of(after,"prop.apple_basket")
    if basket>=0 and "hand" in after.slots[basket].marks and absi(basket-3)<=int(after.reach): value+=5.0
   if after.rule=="ferryman" and not Stage.hidden(after,Stage.slot_of(after,"rival.ferryman")): value+=5.0
 return value

static func play(definition: Dictionary, strategy: String, journey: Dictionary={}, max_turns: int=40) -> Dictionary:
 var options: Dictionary=journey.duplicate(true)
 if strategy=="cautious": options.blanks_disabled=true
 var s: Dictionary=Duel.start(definition,options)
 var commands: Array=[]
 var started: int=Time.get_ticks_msec()
 while s.outcome=="" and int(s.turn)<=max_turns:
  var plan: Array=choose(s,strategy)
  commands.append({"turn":s.turn,"plan":plan.duplicate(true)})
  for action in plan:
   Duel.command(s,action)
   if s.outcome!="": break
  if s.outcome=="": Duel.end_turn(s)
 return {"duel":definition.id,"strategy":strategy,"win":s.outcome=="victory","outcome":s.outcome if s.outcome!="" else "turn_limit","turns":s.turn,"hp":Stage.player_hp(s),"exposed":s.exposed,"exposed_turn":s.get("exposed_turn",null),"reversal":s.reversal_used,"reversal_turn":s.get("reversal_turn",null),"blanks":s.filled,"commands":commands,"duration_ms":Time.get_ticks_msec()-started,"state":s}
