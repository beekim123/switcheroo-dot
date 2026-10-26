extends RefCounted
const Stage = preload("res://scripts/core/stage_state.gd")
const Sign = preload("res://scripts/core/signboard.gd")

static func blow(s: Dictionary, slot: int) -> void:
 if slot>=0 and s.slots[slot]!=null and s.slots[slot].get("lit",false):
  s.slots[slot].lit=false
  var rival: Dictionary=Stage.entity(s,"rival.ferryman")
  if not rival.is_empty(): rival.borrowed=int(rival.get("borrowed",0))+1
  Sign.observe(s,"first_extinguish")
  Stage.emit(s,{"type":"blow","slot":slot})

static func reveal(s: Dictionary) -> void:
 var rival: Dictionary=Stage.entity(s,"rival.ferryman")
 if not rival.is_empty(): rival.revealed_until=int(s.turn)+1
 Sign.observe(s,"first_pole")
 Stage.emit(s,{"type":"reveal"})

static func reversal(s: Dictionary, mode: String, a: int, b: int) -> bool:
 if mode!="item": return false
 var p: int=Stage.player_slot(s)
 var r: int=Stage.slot_of(s,"rival.ferryman")
 if p<0 or r<0 or not (p in [a,b] and r in [a,b]): return false
 var player: Dictionary=s.slots[p]
 var rival: Dictionary=s.slots[r]
 if player.item not in ["held.borrowed_lantern","held.borrowed_lantern_lit","borrowed_lantern","item.borrowed_lantern"] or rival.item not in ["held.empty_lamp","empty_lamp","item.empty_lamp"]: return false
 player.item="held.bright_lantern"
 rival.revealed_until=int(s.turn)+int(s.definition.get("reversal",{}).get("reveal_turns",2))
 if s.exposed and not s.reversal_used:
  for e in s.slots:
   if e!=null and (e.id.begins_with("prop.lamp_post") or e.get("archetype","")=="prop.lamp_post"): e.lit=true
  rival.never_hidden=true
  rival.stun=int(s.definition.get("reversal",{}).get("stun",1))
  Stage.raw_damage(s,r,int(s.definition.get("reversal",{}).get("damage",6)),"reversal")
  return true
 return false
