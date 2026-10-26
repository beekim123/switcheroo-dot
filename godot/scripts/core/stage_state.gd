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
