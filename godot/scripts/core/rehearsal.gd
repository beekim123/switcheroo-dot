extends RefCounted
const Stage = preload("res://scripts/core/stage_state.gd")
const Duel = preload("res://scripts/core/duel_rules.gd")

static func start(definition: Dictionary, journey: Dictionary={}) -> Dictionary:
 var s: Dictionary=Stage.make(definition,journey)
 s.rehearsal=true
 s.goal_kind=definition.goal_kind
 s.swap_limit=int(definition.get("swaps",1))
 s.main_used=not definition.get("main_allowed",false)
 s.item_unlocked=definition.get("mode","position")=="item" or s.item_unlocked
 s.intents=definition.get("intents",[]).duplicate(true)
 for i in range(s.intents.size()): s.intents[i].number=i+1
 return s

static func perform(s: Dictionary) -> bool:
 var before: int=s.events.size()
 for intent in s.intents:
  if s.goal_kind=="light" and not Stage.hidden(s,Stage.slot_of(s,"foe.shadow")): continue
  Duel.resolve_intent(s,intent)
 var success := false
 match str(s.goal_kind):
  "rain": success=Stage.slot_of(s,"prop.flour")>=0
  "geese":
   var hit: Dictionary={}
   for event in s.events.slice(before):
    if event.type=="damage" and int(event.amount)>0: hit[event.id]=true
   success=hit.has("foe.goose_a") and hit.has("foe.goose_b") and not hit.has("char.aming")
  "cart":
   success=Stage.slot_of(s,"char.child")>=0
   for event in s.events.slice(before):
    if event.type=="damage" and event.id=="char.child": success=false
  "purse":
   var purse:=Stage.slot_of(s,"prop.purse")
   var owner:=Stage.slot_of(s,"char.owner")
   success=purse>=0 and owner>=0 and absi(purse-owner)==1
  "key":
   var p:=Stage.player_slot(s)
   var guard:=Stage.slot_of(s,"char.guard")
   success=p>=0 and guard>=0 and s.slots[p].item=="held.key" and s.slots[guard].item!=""
  "light":
   var shadow:=Stage.slot_of(s,"foe.shadow")
   success=shadow>=0 and not Stage.hidden(s,shadow)
 s.outcome="success" if success else "retry"
 Stage.emit(s,{"type":s.outcome})
 return success
