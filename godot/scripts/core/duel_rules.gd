extends RefCounted
const Stage = preload("res://scripts/core/stage_state.gd")
const Swap = preload("res://scripts/core/swap.gd")
const Sign = preload("res://scripts/core/signboard.gd")
const Intents = preload("res://scripts/core/intents.gd")
const Thief = preload("res://scripts/core/rules/rule_thief.gd")
const Ferry = preload("res://scripts/core/rules/rule_ferryman.gd")

static func start(definition: Dictionary, journey: Dictionary={}) -> Dictionary:
 var s: Dictionary=Stage.make(definition,journey)
 Sign.prefill(s,journey)
 s.intents=Intents.publish(s)
 return s

static func damage(s: Dictionary, slot: int, amount: int, source: String="", bypass: bool=false) -> void:
 if slot<0 or slot>=5 or s.slots[slot]==null: Stage.raw_damage(s,slot,amount,source); return
 if not bypass:
  if s.rule=="thief": slot=Thief.redirect(s,slot)
  if s.slots[slot].kind=="player" and not s.get("protected_this_turn",false):
   for i in [slot-1,slot+1]:
    if i>=0 and i<5 and s.slots[i]!=null and int(s.slots[i].get("protect_until",0))==int(s.turn):
     s.slots[i].protect_until=0; s.protected_this_turn=true; slot=i; break
 Stage.raw_damage(s,slot,amount,source)

static func can_main(s: Dictionary, kind: String, target: int=-1) -> bool:
 if s.outcome!="" or s.main_used: return false
 if kind=="guard": return true
 if kind=="heal": return int(s.items.get("item.candied_haw",0))>0
 if target<0 or target>=5 or s.slots[target]==null or Stage.hidden(s,target) or s.slots[target].kind=="player": return false
 if kind=="strike": return absi(target-Stage.player_slot(s))==1
 if kind=="marble": return int(s.items.get("item.marble",0))>0
 return false

static func main_action(s: Dictionary, kind: String, target: int=-1) -> Array:
 var before: int=s.events.size()
 if target>=0 and target<5 and Stage.hidden(s,target): Sign.observe(s,"first_hidden")
 if not can_main(s,kind,target): return []
 s.main_used=true
 var p: Dictionary=s.slots[Stage.player_slot(s)]
 match kind:
  "guard": p.guard+=s.guard_amount; Stage.emit(s,{"type":"guard","amount":s.guard_amount})
  "heal":
   s.items["item.candied_haw"]-=1
   p.hp=mini(int(p.max_hp),int(p.hp)+int(s.definition.get("player",{}).get("heal",6)))
   Stage.emit(s,{"type":"heal","hp":p.hp})
  "marble": s.items["item.marble"]-=1; damage(s,target,int(s.definition.get("player",{}).get("marble_damage",2)),"char.aming")
  "strike": damage(s,target,int(s.strike),"char.aming")
 return s.events.slice(before)

static func preview_main(s: Dictionary, kind: String, target: int=-1) -> Dictionary:
 if not can_main(s,kind,target): return {"ok":false}
 var copy: Dictionary=s.duplicate(true)
 var events: Array=main_action(copy,kind,target)
 return {"ok":true,"state":copy,"events":events}

static func swap(s: Dictionary, mode: String, a: int, b: int) -> Array:
 var before: int=s.events.size()
 if a>=0 and a<5 and Stage.hidden(s,a) or b>=0 and b<5 and Stage.hidden(s,b): Sign.observe(s,"first_hidden")
 if not Swap.apply(s,mode,a,b).ok: return []
 var reversed := false
 if s.rule=="thief": reversed=Thief.reversal(s,mode,a,b)
 elif s.rule=="ferryman": reversed=Ferry.reversal(s,mode,a,b)
 if reversed:
  s.reversal_used=true; s.reversal_turn=s.turn
  Stage.emit(s,{"type":"reversal","id":"return_owner" if s.rule=="thief" else "return_light"})
 return s.events.slice(before)

static func resolve_intent(s: Dictionary, intent: Dictionary) -> void:
 var actor: String=intent.get("actor","environment")
 var e: Dictionary=Stage.entity(s,actor)
 if actor not in ["environment","cupper"] and e.is_empty(): return
 if not e.is_empty() and int(e.stun)>0:
  e.stun-=1; Stage.emit(s,{"type":"stun","id":actor}); return
 Stage.emit(s,{"type":"intent_resolve","intent":intent.duplicate(true)})
 var slot: int=int(intent.get("slot",-1))
 match str(intent.kind):
  "hit", "pole":
   if intent.kind=="pole": Ferry.reveal(s)
   damage(s,slot,int(intent.get("amount",0)),actor)
  "touch": Thief.touch(s,slot)
  "blow", "blow_out", "extinguish": Ferry.blow(s,slot)
  "guard":
   if not e.is_empty(): e.guard+=int(intent.get("amount",2))
  "move", "roll":
   var from: int=Stage.slot_of(s,actor)
   if from>=0 and slot>=0 and (s.slots[slot]==null or not s.slots[slot].heavy):
    var old: Variant=s.slots[slot]; s.slots[slot]=s.slots[from]; s.slots[from]=old
    Stage.emit(s,{"type":"move","a":from,"b":slot})
    if intent.kind=="roll": damage(s,from,int(intent.get("amount",3)),actor)
   else: Stage.emit(s,{"type":"move_failed","slot":slot})
  "swap":
   var a: int=int(intent.a); var b: int=int(intent.b)
   var old: Variant=s.slots[a]; s.slots[a]=s.slots[b]; s.slots[b]=old
  "rain":
   if slot>=0 and s.slots[slot]!=null and s.slots[slot].id!="prop.bucket": damage(s,slot,99,actor,true)
  "steal":
   if slot>=0 and s.slots[slot]!=null:
    Stage.emit(s,{"type":"stolen","id":s.slots[slot].id}); s.slots[slot]=null

static func end_turn(s: Dictionary) -> Array:
 var before: int=s.events.size()
 if s.outcome!="": return []
 for e in s.slots:
  if e!=null and e.kind in ["foe","rival"]: e.guard=0
 for intent in s.intents:
  resolve_intent(s,intent)
  if s.outcome!="": break
 if s.rule=="thief" and s.turn>=2: Sign.observe(s,"granny_shout_t2")
 if s.rule=="ferryman" and s.turn>=2: Sign.observe(s,"first_hidden")
 Stage.check_outcome(s)
 if s.outcome!="": Stage.emit(s,{"type":s.outcome}); return s.events.slice(before)
 s.turn+=1; s.main_used=false; s.swap_used=0; s.protected_this_turn=false
 var p:=Stage.player_slot(s)
 if p>=0: s.slots[p].guard=0
 s.intents=Intents.publish(s)
 Stage.emit(s,{"type":"turn_start"})
 return s.events.slice(before)

static func threats(s: Dictionary) -> Dictionary:
 var copy: Dictionary=s.duplicate(true)
 var index: int=copy.events.size()
 for e in copy.slots:
  if e!=null and e.kind in ["foe","rival"]: e.guard=0
 for intent in copy.intents:
  resolve_intent(copy,intent)
  if copy.outcome!="": break
 var per_slot: Array=[0,0,0,0,0]
 var per_id: Dictionary={}
 for event in copy.events.slice(index):
  if event.type=="damage":
   per_slot[int(event.slot)]+=int(event.amount)
   per_id[event.id]=int(per_id.get(event.id,0))+int(event.amount)
 return {"slots":per_slot,"entities":per_id,"player":int(per_id.get("char.aming",0))}

static func preview_swap(s: Dictionary, mode: String, a: int, b: int) -> Dictionary:
 var valid: Dictionary=Swap.can(s,mode,a,b)
 if not valid.ok: return valid
 var copy: Dictionary=s.duplicate(true)
 var before: bool=copy.reversal_used
 swap(copy,mode,a,b)
 return {"ok":true,"reason":"","state":copy,"ghost_positions":copy.slots,"threats":threats(copy),"reversal":copy.reversal_used and not before}

static func legal_actions(s: Dictionary) -> Array:
 var actions: Array=[]
 for kind in ["guard","heal","strike","marble"]:
  if kind in ["guard","heal"]:
   if can_main(s,kind): actions.append({"kind":kind,"target":-1})
  else:
   for i in range(5):
    if can_main(s,kind,i): actions.append({"kind":kind,"target":i})
 for mode in ["position","item"]:
  for a in range(5):
   for b in range(a+1,5):
    if Swap.can(s,mode,a,b).ok: actions.append({"kind":"swap","mode":mode,"a":a,"b":b})
 return actions

static func command(s: Dictionary, action: Dictionary) -> void:
 if action.kind=="swap": swap(s,action.mode,int(action.a),int(action.b))
 else: main_action(s,action.kind,int(action.get("target",-1)))
