extends SceneTree
const Stage = preload("res://scripts/core/stage_state.gd")
var failed := 0
var checks := 0

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failed += 1
  push_error("FAIL: " + label)

func _initialize() -> void:
 var stage := Stage.new()
 check(stage.slots.size() == 5, "five slots")
 check(stage.put(0, {"id": "aming", "hp": 20}), "place player")
 check(stage.put(1, {"id": "moondust", "hp": 5}), "place enemy")
 check(not stage.put(1, {"id": "collision", "hp": 5}), "reject occupied slot")
 var locked_slot := 0
 check(stage.swap_positions(0, 1), "legal position swap")
 var hit: Dictionary = stage.resolve_hit(locked_slot, 3)
 check(hit.id == "moondust" and hit.hp == 2, "intent stays on slot and hits attacker")
 check(stage.slots[1].hp == 20, "player remains unharmed")
 check(not stage.swap_positions(0, 4), "distance cap")
 check(not stage.swap_positions(3, 4), "empty-empty invalid")
 stage.put(2, {"id": "statue", "hp": 99, "heavy": true})
 check(not stage.swap_positions(1, 2), "heavy blocks swap")
 stage.put(3, {"id": "hidden", "hp": 5, "hidden": true})
 check(not stage.swap_positions(1, 3), "hidden blocks selection")
 print("D0 rule checks: ", checks, "; failures: ", failed)
 quit(1 if failed else 0)
