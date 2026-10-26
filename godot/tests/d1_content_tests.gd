extends SceneTree
## Independent content/contract regression suite. No rendering or persistent save writes.
const Duel = preload("res://scripts/core/duel_rules.gd")
const Stage = preload("res://scripts/core/stage_state.gd")
const Swap = preload("res://scripts/core/swap.gd")
const Sign = preload("res://scripts/core/signboard.gd")
const Rehearsal = preload("res://scripts/core/rehearsal.gd")
const Solver = preload("res://scripts/core/solver.gd")
const Journey = preload("res://scripts/core/journey_state.gd")
const Bots = preload("res://scripts/core/bots.gd")
const Intents = preload("res://scripts/core/intents.gd")
var checks := 0
var failures := 0
var duels: Dictionary = {}
var rehearsals: Array = []

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("D1 contract: " + label)

func event_count(state: Dictionary, type: String) -> int:
 var total := 0
 for event in state.events:
  if event.type == type: total += 1
 return total

func fresh(id: String, journey: Dictionary = {}) -> Dictionary:
 return Duel.start(duels[id], journey)

func _initialize() -> void:
 var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/data/duels.json"))
 for definition in authored.duels: duels[definition.id] = definition
 rehearsals = JSON.parse_string(FileAccess.get_file_as_string("res://data/data/rehearsals.json")).rehearsals
 if "--tune-ferry" in OS.get_cmdline_user_args():
  _tune_ferry(); quit(); return
 check(duels.size() == 3, "three authored duels")
 check(rehearsals.size() == 6, "six authored rehearsals")
 _solver_contracts()
 _tutorial_contracts()
 _swap_contracts()
 _thief_contracts()
 _ferryman_contracts()
 _turn_contracts()
 _journey_inputs()
 _preview_guard_regression()
 _finite_progression_contracts()
 _once_only_reversal_contract()
 _mark_once_per_turn_contract()
 _corrupt_save_contracts()
 _guard_target_contract()
 _authored_number_contracts()
 print("D1 independent content/rule assertions: ", checks, "; failures: ", failures)
 quit(1 if failures else 0)

func _solver_contracts() -> void:
 for definition in rehearsals:
  var state: Dictionary = Rehearsal.start(definition)
  check(not Rehearsal.perform(state), str(definition.id) + " cannot win without solving")
  var solutions: Array = Solver.solve(definition)
  check(not solutions.is_empty(), str(definition.id) + " has at least one solution")
  for path in solutions:
   var replay: Dictionary = Rehearsal.start(definition)
   for action in path: Duel.command(replay, action)
   check(Rehearsal.perform(replay), str(definition.id) + " solver result actually wins")
   check(int(replay.swap_used) <= int(definition.swaps), str(definition.id) + " respects swap budget")
  print("Rehearsal ", definition.id, ": ", solutions.size(), " solutions")

func _tutorial_contracts() -> void:
 var s: Dictionary = fresh("duel.prologue")
 check(not Swap.can(s, "position", 0, 1).ok, "tutorial first turn has no swap")
 check(s.intents.size() == 3, "tutorial publishes three ordered intents")
 Duel.main_action(s, "strike", 1)
 Duel.end_turn(s)
 check(Stage.player_slot(s) == 2 and Stage.player_hp(s) == 17, "tutorial uncontrolled swap changes victim")
 check(Stage.entity(s, "prop.crate").hp == 3, "tutorial crate takes first moon hit")
 check(Swap.can(s, "position", 1, 2).ok, "tutorial unlocks swap in turn two")
 var before := JSON.stringify(s)
 var preview: Dictionary = Duel.preview_swap(s, "position", 1, 2)
 check(preview.ok and preview.threats.player == 0, "preview finds safe self-hit solution")
 check(JSON.stringify(s) == before, "preview is mutation-free")
 Duel.swap(s, "position", 1, 2)
 check(s.intents[0].slot == 2 and s.intents[1].slot == 2, "published targets remain locked")
 Duel.end_turn(s)
 check(Stage.slot_of(s, "foe.moondust_a") == -1 and Stage.player_hp(s) == 17, "self-hit moon flees and player stays safe")
 check(event_count(s, "self_hit") >= 1, "self-hit emits audience-readable event")
 var replay: Dictionary = fresh("duel.prologue")
 Duel.main_action(replay, "strike", 1); Duel.end_turn(replay); Duel.swap(replay, "position", 1, 2); Duel.end_turn(replay)
 check(JSON.stringify(replay) == JSON.stringify(s), "fixed command replay is deterministic")

func _swap_contracts() -> void:
 var s: Dictionary = fresh("duel.thief")
 check(not Swap.can(s, "position", 0, 4).ok, "position swap rejects distance and heavy")
 check(not Swap.can(s, "position", 3, 4).ok, "position swap rejects heavy owner stall")
 check(not Swap.can(s, "item", 0, 2).ok, "item swap locked before act three")
 s.slots[1] = null; s.slots[2] = null
 check(not Swap.can(s, "position", 1, 2).ok, "two empty positions cannot swap")
 check(Swap.can(s, "position", 0, 2).ok, "one empty position may swap")
 Duel.swap(s, "position", 0, 2)
 check(not Swap.can(s, "position", 1, 2).ok, "swap shared budget enforced")
 var r: Dictionary = Rehearsal.start(rehearsals[4])
 check(Swap.can(r, "item", 0, 2).ok, "two held items can exchange")
 r.slots[2].item = ""
 check(not Swap.can(r, "item", 0, 2).ok, "empty hand rejects item exchange")
 check(not Swap.can(r, "position", -1, 2).ok, "invalid target index rejected")

func _thief_contracts() -> void:
 var s: Dictionary = fresh("duel.thief", {"clues":["clue.market.cloth", "clue.market.granny"]})
 check(s.filled.size() == 2 and not s.exposed, "investigation cannot fill stage-only block")
 Duel.end_turn(s)
 check("hand" in Stage.entity(s, "prop.apple_basket").marks, "thief touches left adjacent prop first")
 Duel.main_action(s, "marble", 2)
 check(Stage.entity(s, "rival.thief").hp == 16 and Stage.entity(s, "prop.apple_basket").hp == 4, "marked adjacent prop redirects rival damage")
 check(s.exposed and s.filled.has("block"), "first actual block exposes signboard")
 var pv: Dictionary = Duel.preview_swap(s, "position", 1, 3)
 check(pv.ok and pv.reversal, "return-owner preview announces reversal")
 Duel.swap(s, "position", 1, 3)
 check(s.reversal_used and Stage.entity(s, "rival.thief").hp == 10, "return owner deals six bypass damage")
 check(Stage.entity(s, "rival.thief").stun == 1, "return owner stuns one intent")
 check(not "hand" in Stage.entity(s, "prop.apple_basket").marks, "return owner clears handprints")
 Duel.end_turn(s)
 check(event_count(s, "stun") == 1, "stun skips next intent exactly once")
 check(event_count(s, "reversal") == 1, "reversal emits once")
 var base: Dictionary = fresh("duel.thief")
 Duel.end_turn(base); Duel.swap(base, "position", 1, 3)
 check(not base.reversal_used and Stage.entity(base, "rival.thief").hp == 16, "same swap before exposure only clears handprint")
 var memory: Dictionary = fresh("duel.thief", {"known_blanks":{"duel.thief":s.filled}})
 check(memory.exposed, "retry preserves learned blanks")

func _ferryman_contracts() -> void:
 var s: Dictionary = fresh("duel.ferryman")
 check(Stage.is_lit(s,0) and Stage.is_lit(s,2) and not Stage.is_lit(s,4), "lamps illuminate self and adjacent positions only")
 check(Stage.hidden(s,4), "ferryman begins hidden despite holding borrowed light")
 check(not Duel.can_main(s,"marble",4) and not Swap.can(s,"item",0,4).ok, "hidden rival cannot be selected")
 Duel.main_action(s,"marble",4)
 check(s.filled.has("hidden"), "trying to select hidden rival teaches hidden blank")
 Duel.swap(s,"position",1,3)
 check(not Stage.hidden(s,4), "moving a lamp immediately reveals the rival")
 Duel.end_turn(s)
 check(Stage.entity(s,"prop.lamp_a").lit, "extinguish intent stays at now-dark original position")
 var f: Dictionary = fresh("duel.ferryman", {"clues":["clue.ferry.fish","clue.ferry.scholar"]})
 Duel.main_action(f,"guard"); Duel.end_turn(f)
 check(not Stage.entity(f,"prop.lamp_a").lit and f.filled.has("lamp"), "actual extinguish fills stage-only lamp blank")
 check(f.exposed, "ferry clues plus on-stage extinguish expose rule")
 Duel.main_action(f,"guard"); Duel.end_turn(f)
 check(not Stage.hidden(f,4), "pole intent reveals ferryman for the next player turn")
 check(Swap.can(f,"item",0,4).ok, "item exchange ignores four-position distance")
 Duel.swap(f,"item",0,4)
 check(f.reversal_used and Stage.entity(f,"rival.ferryman").hp == int(duels["duel.ferryman"].layout[4].hp)-6, "return light reversal deals six damage")
 check(Stage.entity(f,"rival.ferryman").never_hidden, "return light removes invisibility permanently")
 check(Stage.entity(f,"prop.lamp_a").lit and Stage.entity(f,"prop.lamp_b").lit, "return light restores both lamps")
 check(Stage.is_lit(f,0), "held returned light illuminates player")

func _turn_contracts() -> void:
 var s: Dictionary = fresh("duel.thief")
 s.intents = [{"actor":"rival.thief","kind":"move","slot":4,"amount":0}]
 Duel.end_turn(s)
 check(Stage.slot_of(s,"rival.thief") == 2, "movement into heavy prop fails without displacement")
 check(event_count(s,"move_failed") == 1, "failed movement is visible event")
 var h: Dictionary = fresh("duel.thief")
 h.intents = [{"actor":"rival.thief","kind":"hit","slot":0,"amount":3},{"actor":"rival.thief","kind":"hit","slot":0,"amount":3}]
 Duel.main_action(h,"guard")
 check(Duel.threats(h).player == 2, "two intents share and consume guard in preview")
 Duel.end_turn(h)
 check(Stage.player_hp(h) == 18 and Stage.entity(h,"char.aming").guard == 0, "ordered hits then next-turn guard clear")
 var win: Dictionary = fresh("duel.thief")
 win.slots[2].hp = 1
 Duel.main_action(win,"marble",2)
 check(win.outcome == "victory", "rival defeat wins immediately")
 var before: int = Stage.player_hp(win)
 Duel.end_turn(win)
 check(Stage.player_hp(win) == before, "no enemy intents after victory")
 var lose: Dictionary = fresh("duel.thief")
 lose.slots[0].hp = 1
 lose.intents = [{"actor":"rival.thief","kind":"hit","slot":0,"amount":4}]
 Duel.end_turn(lose)
 check(lose.outcome == "defeat", "zero player hp ends duel immediately")
 var prop: Dictionary = fresh("duel.thief")
 prop.slots[1].marks = ["hand"]
 Stage.raw_damage(prop,1,6)
 check(prop.slots[1] == null, "destroyed prop removes its handprints with occupant")

func _journey_inputs() -> void:
 var s: Dictionary = fresh("duel.thief", {"upgrades":{"up.sturdy":2,"up.reach":1,"up.marble":1,"up.foresight":1},"assist":true})
 check(Stage.player_hp(s) == 28 and s.reach == 3 and s.items["item.marble"] == 3 and s.foresight, "all four upgrades affect new duel")
 check(Stage.entity(s,"rival.thief").hp == 12, "assist reduces rival hp by thirty percent rounded upward")
 var no_blanks: Dictionary = fresh("duel.thief", {"blanks_disabled":true,"clues":["clue.market.cloth","clue.market.granny"]})
 Duel.end_turn(no_blanks)
 check(no_blanks.filled.is_empty() and not no_blanks.exposed, "bot proof can disable recognition entirely")

func _preview_guard_regression() -> void:
 var s: Dictionary = fresh("duel.thief")
 s.slots[2].guard = 4
 s.intents = [{"actor":"rival.thief","kind":"hit","slot":2,"amount":4}]
 var threat: Dictionary = Duel.threats(s)
 check(int(threat.entities.get("rival.thief",0)) == 4, "threat preview clears enemy guard like actual enemy turn")
 Duel.end_turn(s)
 check(Stage.entity(s,"rival.thief").hp == 12, "enemy guard clears before self-hit resolves")

func _finite_progression_contracts() -> void:
 var j: Dictionary = Journey.fresh()
 check(Journey.valid({"journey":j}), "fresh journey validates")
 check(Journey.reward(j,"reh.rain"), "first rehearsal success grants insight")
 check(not Journey.reward(j,"reh.rain") and j.insight == 1, "repeated rehearsal cannot farm insight")
 var upgrades: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/data/upgrades.json")).upgrades
 check(not Journey.buy(j,upgrades[0]) and j.insight == 1, "unaffordable upgrade spends nothing")
 check(Journey.buy(j,upgrades[2]) and j.insight == 0, "affordable upgrade applies once")
 j.insight = 8
 check(Journey.buy(j,upgrades[2]) and not Journey.buy(j,upgrades[2]) and j.upgrades["up.sturdy"] == 2, "sturdy purchase cap enforced")
 check(Journey.buy(j,upgrades[0]) and not Journey.buy(j,upgrades[0]), "reach purchase cap enforced")
 check(not Journey.valid({}), "missing journey safely rejected")
 check(not Journey.valid({"journey":{"format":"journey/2"}}), "unknown save version safely rejected")

func _once_only_reversal_contract() -> void:
 var s: Dictionary = fresh("duel.thief", {"known_blanks":{"duel.thief":{"touch":{},"owner":{},"block":{}}}})
 s.reversal_used = true
 s.slots[1].marks = ["hand"]
 var preview: Dictionary = Duel.preview_swap(s,"position",1,3)
 check(preview.ok and not preview.reversal, "repeat specific swap preview is only base effect")
 Duel.swap(s,"position",1,3)
 check(Stage.entity(s,"rival.thief").hp == 16 and event_count(s,"reversal") == 0, "used reversal never damages twice")
 check(not "hand" in Stage.entity(s,"prop.apple_basket").marks, "repeat specific swap still clears handprint")
 var f: Dictionary = fresh("duel.ferryman")
 Duel.swap(f,"position",1,3); Duel.end_turn(f)
 Duel.swap(f,"item",0,4)
 check(not f.exposed and not f.reversal_used and Stage.entity(f,"rival.ferryman").hp == int(duels["duel.ferryman"].layout[4].hp), "unexposed light swap has no bonus damage")
 check(int(Stage.entity(f,"rival.ferryman").revealed_until) == int(f.turn)+2, "base light swap reveals for two turns")

func _mark_once_per_turn_contract() -> void:
 var definition: Dictionary = duels["duel.thief"].duplicate(true)
 var player: Dictionary = definition.layout[0]
 definition.layout[0] = definition.layout[2]
 definition.layout[2] = player
 var s: Dictionary = Duel.start(definition,{"mark":"mark.missing"})
 Duel.swap(s,"position",1,3)
 s.intents = [{"actor":"rival.thief","kind":"hit","slot":2,"amount":1},{"actor":"rival.thief","kind":"hit","slot":2,"amount":1}]
 Duel.end_turn(s)
 check(Stage.player_hp(s) == 19, "missing mark blocks at most one attack per turn even with two adjacent swapped props")

func _corrupt_save_contracts() -> void:
 check(not Journey.valid({"journey":"wrong"}), "wrong journey container rejected")
 check(not Journey.valid({"journey":[]}), "array journey container rejected")
 for field in ["clues","motives","completed","marks"]:
  var j: Dictionary = Journey.fresh(); j[field] = "wrong"
  check(not Journey.valid({"journey":j}), "corrupt array field rejected: " + field)
  j = Journey.fresh(); j[field] = [42]
  check(not Journey.valid({"journey":j}), "corrupt array member rejected: " + field)
 for field in ["visited","upgrades","letters","known_blanks"]:
  var j: Dictionary = Journey.fresh(); j[field] = "wrong"
  check(not Journey.valid({"journey":j}), "corrupt dictionary field rejected: " + field)
 for field in ["hint","assist","finished"]:
  var j: Dictionary = Journey.fresh(); j[field] = "true"
  check(not Journey.valid({"journey":j}), "corrupt boolean field rejected: " + field)
 for field in ["act","story_index","insight","unlocked","rehearsal_index","elapsed_seconds"]:
  var j: Dictionary = Journey.fresh(); j[field] = "wrong"
  check(not Journey.valid({"journey":j}), "corrupt numeric field rejected: " + field)
 var nested: Dictionary = Journey.fresh(); nested.visited = {"inv.market":"wrong"}
 check(not Journey.valid({"journey":nested}), "corrupt nested visited data rejected")
 nested = Journey.fresh(); nested.known_blanks = {"duel.thief":"wrong"}
 check(not Journey.valid({"journey":nested}), "corrupt nested signboard memory rejected")
 nested = Journey.fresh(); nested.letters = {"1":"wrong"}
 check(not Journey.valid({"journey":nested}), "corrupt nested letter rejected")
 nested = Journey.fresh(); nested.upgrades = {"up.sturdy":3}
 check(not Journey.valid({"journey":nested}), "over-limit upgrade save rejected")
 nested = Journey.fresh(); nested.act = 1.5
 check(not Journey.valid({"journey":nested}), "fractional act cannot produce a missing content id")
 nested = Journey.fresh(); nested.marks = ["mark.missing_typo"]
 check(not Journey.valid({"journey":nested}), "unknown mark cannot produce a missing shop record")
 var roundtrip: Dictionary = JSON.parse_string(JSON.stringify({"journey":Journey.fresh()}))
 check(Journey.valid(roundtrip), "JSON numeric roundtrip retains a valid save")
 var normalized: Dictionary = Journey.normalize(roundtrip.journey)
 check("act." + str(normalized.act) == "act.1", "normalized JSON act retains content lookup id")
 check(Journey.valid({"journey":normalized}), "normalized save remains valid")

func _tune_ferry() -> void:
 var definition: Dictionary = duels["duel.ferryman"].duplicate(true)
 for entity in definition.layout:
  if entity != null and entity.id == "rival.ferryman":
   entity.hp = 24; entity.max_hp = 24
 for strategy in ["cautious","lookahead","no_swap"]:
  var result: Dictionary = Bots.play(definition,strategy)
  result.erase("state"); result.erase("commands")
  print("FERRY24 ", JSON.stringify(result))

func _guard_target_contract() -> void:
 var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/data/roads.json")).roads
 var s: Dictionary = Duel.start(roads[0])
 s.turn = 2
 s.intents = Intents.publish(s)
 var guard_count := 0
 for intent in s.intents:
  if intent.kind != "guard": continue
  guard_count += 1
  check(int(intent.slot) == Stage.slot_of(s,str(intent.actor)), "guard intent points to its actor, not player")
 check(guard_count == 2, "both rolling apples publish guard on second cycle beat")
 Duel.swap(s,"position",0,1)
 var republished: Array = Intents.publish(s)
 for intent in republished:
  if intent.kind != "guard": continue
  check(int(intent.slot) == Stage.slot_of(s,str(intent.actor)), "guard self target does not follow player movement")
  Stage.entity(s,"char.aming").guard = 3
  Duel.resolve_intent(s,intent)
  check(int(Stage.entity(s,str(intent.actor)).guard) == int(intent.amount), "guard grants protection to actor")
  check(int(Stage.entity(s,"char.aming").guard) == 3, "guard never grants protection to player target slot")

func _authored_number_contracts() -> void:
 var definition: Dictionary = duels["duel.thief"].duplicate(true)
 definition.player.heal = 9
 definition.player.marble_damage = 3
 definition.reversal.damage = 8
 definition.reversal.stun = 2
 var healing: Dictionary = Duel.start(definition)
 Stage.entity(healing,"char.aming").hp = 5
 Duel.main_action(healing,"heal")
 check(Stage.player_hp(healing) == 14, "heal amount is read from authored player configuration")
 var marble: Dictionary = Duel.start(definition)
 Duel.main_action(marble,"marble",2)
 check(Stage.entity(marble,"rival.thief").hp == 13, "marble damage is read from authored player configuration")
 var reversal: Dictionary = Duel.start(definition,{"known_blanks":{"duel.thief":{"touch":{},"owner":{},"block":{}}}})
 reversal.slots[1].marks = ["hand"]
 Duel.swap(reversal,"position",1,3)
 check(Stage.entity(reversal,"rival.thief").hp == 8, "reversal damage is read from authored configuration")
 check(Stage.entity(reversal,"rival.thief").stun == 2, "reversal stun is read from authored configuration")
 var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/data/roads.json")).roads
 var road: Dictionary = roads[1].duplicate(true)
 road.layout[1].explode = 5
 var blast: Dictionary = Duel.start(road)
 Stage.raw_damage(blast,1,4,"char.aming")
 check(Stage.player_hp(blast) == 15, "water lantern blast amount is read from authored entity configuration")
