extends RefCounted
const Stage = preload("res://scripts/core/stage_state.gd")

static func publish(s: Dictionary) -> Array:
 var result: Array=[]
 if s.rule=="prologue" and s.turn<=2:
  if s.turn==1: result.append({"actor":"cupper","kind":"swap","a":0,"b":2,"slot":2,"amount":0})
  for i in range(5):
   var e: Variant=s.slots[i]
   if e!=null and e.kind=="foe": result.append({"actor":e.id,"kind":"hit","amount":3,"slot":0 if s.turn==1 and i==1 else 2})
 else:
  for i in range(5):
   var e: Variant=s.slots[i]
   if e==null or not e.kind in ["foe","rival"]: continue
   var cycle: Array=e.get("cycle",s.definition.get("intent_cycle",[]))
   if cycle.is_empty(): cycle=[{"kind":"hit","amount":3,"target":"player"}]
   var intent: Dictionary=cycle[(int(s.turn)-1)%cycle.size()].duplicate(true)
   intent.actor=e.id
   var target: String=str(intent.get("target","player"))
   var target_slot := Stage.player_slot(s)
   match target:
    "self": target_slot=i
    "adjacent_unmarked_prop":
     target_slot=-1
     for j in [i-1,i+1]:
      if j>=0 and j<5 and s.slots[j]!=null and s.slots[j].kind=="prop" and not s.slots[j].heavy and not "hand" in s.slots[j].marks:
       target_slot=j; break
     if target_slot<0: intent.kind="hit"; intent.amount=4; target_slot=Stage.player_slot(s)
    "nearest_lit_lamp":
     target_slot=-1
     for j in range(5):
      if s.slots[j]!=null and s.slots[j].get("lit",false) and (target_slot<0 or absi(j-i)<absi(target_slot-i)): target_slot=j
     if target_slot<0: intent.kind="pole"; intent.amount=5; target_slot=Stage.player_slot(s)
    "adjacent_empty":
     target_slot=-1
     for j in [i-1,i+1]:
      if j>=0 and j<5 and s.slots[j]==null: target_slot=j; break
     if target_slot<0: intent.kind="hit"; intent.amount=3; target_slot=Stage.player_slot(s)
    "farthest_not_heavy", "farthest_from_aming_not_heavy", "farthest_dark":
     target_slot=i
     for j in range(5):
      if s.slots[j]!=null and s.slots[j].heavy: continue
      if target=="farthest_dark" and Stage.is_lit(s,j): continue
      if absi(j-Stage.player_slot(s))>absi(target_slot-Stage.player_slot(s)): target_slot=j
   intent.slot=int(intent.get("slot",target_slot))
   intent.amount=int(intent.get("amount",intent.get("n",0)))
   result.append(intent)
 for i in range(result.size()): result[i].number=i+1
 return result
