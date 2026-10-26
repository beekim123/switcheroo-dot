extends RefCounted
const Stage = preload("res://scripts/core/stage_state.gd")
const Sign = preload("res://scripts/core/signboard.gd")

static func touch(s: Dictionary, slot: int) -> void:
 if slot>=0 and s.slots[slot]!=null and s.slots[slot].kind=="prop" and not s.slots[slot].heavy:
  if not "hand" in s.slots[slot].marks: s.slots[slot].marks.append("hand")
  Stage.emit(s,{"type":"touch","slot":slot})
  Sign.observe(s,"first_touch")

static func redirect(s: Dictionary, slot: int) -> int:
 if s.slots[slot]==null or s.slots[slot].id!="rival.thief": return slot
 for i in [slot-1,slot+1]:
  if i>=0 and i<5 and s.slots[i]!=null and "hand" in s.slots[i].marks:
   Sign.observe(s,"first_block")
   Stage.emit(s,{"type":"redirect_hit","from":slot,"to":i})
   return i
 return slot

static func reversal(s: Dictionary, mode: String, a: int, b: int) -> bool:
 if mode!="position": return false
 for i in [a,b]:
  if s.slots[i]!=null and s.slots[i].id=="prop.apple_basket" and "hand" in s.slots[i].marks:
   var owner := Stage.slot_of(s,"prop.stall")
   if owner>=0 and absi(i-owner)==1:
    s.slots[i].marks.erase("hand")
    if s.exposed and not s.reversal_used:
     for e in s.slots:
      if e!=null: e.marks.erase("hand")
     var rival: Dictionary=Stage.entity(s,"rival.thief")
     if not rival.is_empty(): rival.stun=int(s.definition.get("reversal",{}).get("stun",1))
     Stage.raw_damage(s,Stage.slot_of(s,"rival.thief"),int(s.definition.get("reversal",{}).get("damage",6)),"reversal")
     return true
 return false
