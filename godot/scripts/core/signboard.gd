extends RefCounted
const Stage = preload("res://scripts/core/stage_state.gd")

static func fill(s: Dictionary, blank: String, source: String) -> void:
 if s.get("blanks_disabled",false) or s.signboard.is_empty() or s.filled.has(blank): return
 if not s.signboard.blanks.has(blank): return
 s.filled[blank] = {"turn":s.turn,"source":source}
 Stage.emit(s,{"type":"blank_filled","blank":blank,"source":source})
 if s.filled.size() == s.signboard.blanks.size() and not s.exposed:
  s.exposed=true
  s.exposed_turn=s.turn
  Stage.emit(s,{"type":"exposed"})

static func observe(s: Dictionary, trigger: String) -> void:
 if s.signboard.is_empty(): return
 for key in s.signboard.blanks:
  if s.signboard.blanks[key].stage == trigger: fill(s,key,"stage")

static func prefill(s: Dictionary, journey: Dictionary) -> void:
 if s.signboard.is_empty(): return
 var saved: Dictionary = journey.get("known_blanks",{}).get(s.id,{})
 for key in saved: fill(s,key,"remembered")
 for key in s.signboard.blanks:
  var clue: Variant = s.signboard.blanks[key].get("clue")
  if clue != null and clue in journey.get("clues",[]): fill(s,key,"clue")

static func sentence(s: Dictionary) -> String:
 if s.signboard.is_empty(): return "没有怪规则：看清意图，再交换。"
 var value: String = s.signboard.text
 for key in s.signboard.blanks:
  value=value.replace("{"+key+"}","（"+str(s.signboard.blanks[key].word if s.filled.has(key) else "　")+"）")
 return value
