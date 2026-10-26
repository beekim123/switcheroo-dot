extends SceneTree
const Stage = preload("res://scripts/core/stage_state.gd")

func _initialize() -> void:
 var success := 0
 for i in range(100):
  var stage := Stage.new()
  stage.put(0, {"id": "aming", "hp": 20})
  stage.put(1, {"id": "moondust", "hp": 5})
  stage.swap_positions(0, 1)
  var result: Dictionary = stage.resolve_hit(0, 3)
  if result.id == "moondust" and result.hp == 2 and stage.slots[1].hp == 20:
   success += 1
 print("D0 deterministic fixture replay: ", success, "/100. D1 duel bots and rehearsal solver NOT IMPLEMENTED / NOT CLAIMED.")
 quit(0 if success == 100 else 1)
