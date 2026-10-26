extends RefCounted
## D0 pure-rule fixture. D1 adds the complete authored duel rules.
const SLOT_COUNT := 5
var slots: Array = [null, null, null, null, null]

func put(slot: int, entity: Dictionary) -> bool:
 if slot < 0 or slot >= SLOT_COUNT or slots[slot] != null:
  return false
 slots[slot] = entity.duplicate(true)
 return true

func swap_positions(a: int, b: int) -> bool:
 if a < 0 or b < 0 or a >= SLOT_COUNT or b >= SLOT_COUNT or a == b or absi(a-b) > 2:
  return false
 if slots[a] == null and slots[b] == null:
  return false
 for slot: int in [a, b]:
  if slots[slot] != null and (slots[slot].get("heavy", false) or slots[slot].get("hidden", false)):
   return false
 var old: Variant = slots[a]
 slots[a] = slots[b]
 slots[b] = old
 return true

func resolve_hit(target_slot: int, damage: int) -> Dictionary:
 if target_slot < 0 or target_slot >= SLOT_COUNT or slots[target_slot] == null:
  return {"type": "miss", "slot": target_slot}
 var target: Dictionary = slots[target_slot]
 target.hp = maxi(0, int(target.hp) - damage)
 var result := {"type": "damage", "slot": target_slot, "id": target.id, "hp": target.hp}
 if target.hp == 0:
  slots[target_slot] = null
 return result

static func make(definition: Dictionary, journey: Dictionary = {}) -> Dictionary:
 var p: Dictionary = definition.get("player", {"hp":20,"strike":4,"guard":4,"reach":2,"items":{"item.candied_haw":1,"item.marble":2}}).duplicate(true)
 var upgrades: Dictionary = journey.get("upgrades", {})
 var state: Dictionary = {"id":definition.id,"slots":definition.layout.duplicate(true),"turn":1,"main_used":false,"swap_used":0,"swap_limit":1,"reach":int(p.get("reach",2))+int(upgrades.get("up.reach",0)),"item_unlocked":int(definition.get("act",1))>=3,"strike":int(p.get("strike",4)),"guard_amount":int(p.get("guard",4)),"items":p.get("items",{}).duplicate(true),"rule":definition.get("rule","none"),"signboard":definition.get("signboard",{}).duplicate(true),"filled":{},"exposed":false,"reversal_used":false,"intents":[],"outcome":"","events":[],"mark":journey.get("mark",""),"hint":journey.get("hint",false),"assist":journey.get("assist",false),"foresight":int(upgrades.get("up.foresight",0))>0,"definition":definition.duplicate(true),"enemy_initial_hp":0,"blanks_disabled":journey.get("blanks_disabled",false),"light_rules":int(definition.get("act",1))>=3}
 state.items["item.marble"] = int(state.items.get("item.marble",2)) + int(upgrades.get("up.marble",0))
 for e in state.slots:
  if e == null: continue
  for key in {"guard":0,"heavy":false,"unbreakable":false,"item":"","marks":[],"lit":false,"stealth":false,"stun":0,"revealed_until":0,"glow_until":0,"owner":""}:
   if not e.has(key): e[key] = {"guard":0,"heavy":false,"unbreakable":false,"item":"","marks":[],"lit":false,"stealth":false,"stun":0,"revealed_until":0,"glow_until":0,"owner":""}[key]
  if not e.has("max_hp"): e.max_hp = e.get("hp",0)
  if e.kind == "player":
   e.max_hp = int(p.get("hp",20)) + int(upgrades.get("up.sturdy",0))*4
   e.hp = e.max_hp
  elif e.kind in ["foe","rival"]:
   if state.assist: e.hp = maxi(1,int(ceil(float(e.hp)*0.7)))
   state.enemy_initial_hp += int(e.hp)
 return state

static func slot_of(s: Dictionary, id: String) -> int:
 for i in range(SLOT_COUNT):
  if s.slots[i] != null and s.slots[i].id == id: return i
 return -1

static func player_slot(s: Dictionary) -> int:
 for i in range(SLOT_COUNT):
  if s.slots[i] != null and s.slots[i].kind == "player": return i
 return -1

static func entity(s: Dictionary, id: String) -> Dictionary:
 var i := slot_of(s,id)
 return s.slots[i] if i >= 0 else {}

static func is_lit(s: Dictionary, slot: int) -> bool:
 for i in range(maxi(0,slot-1),mini(SLOT_COUNT,slot+2)):
  var e: Variant = s.slots[i]
  if e != null and (e.get("lit",false) or e.get("item","") in ["held.bright_lantern","held.borrowed_lantern_lit"] or int(e.get("glow_until",0))>=int(s.turn)):
   return true
 return false

static func hidden(s: Dictionary, slot: int) -> bool:
 if slot < 0 or slot >= SLOT_COUNT or s.slots[slot] == null: return false
 var e: Dictionary = s.slots[slot]
 if e.get("hidden",false): return true
 return e.get("stealth",false) and not e.get("never_hidden",false) and int(e.get("revealed_until",0)) < int(s.turn) and not is_lit(s,slot)

static func emit(s: Dictionary, event: Dictionary) -> void:
 event["turn"] = s.turn
 s.events.append(event)

static func raw_damage(s: Dictionary, slot: int, amount: int, source: String = "") -> void:
 if slot < 0 or slot >= SLOT_COUNT or s.slots[slot] == null:
  emit(s,{"type":"miss","slot":slot}); return
 var e: Dictionary = s.slots[slot]
 if e.get("unbreakable",false):
  emit(s,{"type":"blocked","id":e.id,"slot":slot}); return
 var blocked := mini(int(e.get("guard",0)),amount)
 e.guard = int(e.get("guard",0))-blocked
 var taken := mini(int(e.hp),maxi(0,amount-blocked))
 e.hp = maxi(0,int(e.hp)-taken)
 emit(s,{"type":"damage","id":e.id,"slot":slot,"amount":taken,"blocked":blocked,"source":source})
 if source == e.id: emit(s,{"type":"self_hit","id":e.id})
 if int(e.hp)<=0:
  s.slots[slot]=null
  emit(s,{"type":"exit","id":e.id})
  if e.kind == "player": s.outcome="defeat"
  elif e.kind == "rival": s.outcome="victory"
  if e.get("archetype","") == "foe.water_lantern" or e.id.begins_with("foe.water_lantern"):
   for neighbor in [slot-1,slot+1]:
    if neighbor>=0 and neighbor<SLOT_COUNT and s.outcome=="": raw_damage(s,neighbor,int(e.get("explode",{}).get("damage",2)) if e.get("explode") is Dictionary else int(e.get("explode",2)),e.id)
  check_outcome(s)

static func check_outcome(s: Dictionary) -> void:
 if s.outcome != "": return
 if player_slot(s)<0: s.outcome="defeat"; return
 for e in s.slots:
  if e != null and e.kind in ["foe","rival"]: return
 if not s.get("rehearsal",false): s.outcome="victory"

static func player_hp(s: Dictionary) -> int:
 var slot := player_slot(s)
 return int(s.slots[slot].hp) if slot>=0 else 0

static func enemy_hp(s: Dictionary) -> int:
 var total := 0
 for e in s.slots:
  if e != null and e.kind in ["foe","rival"]: total+=int(e.hp)
 return total
