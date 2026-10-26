extends RefCounted

static func fresh() -> Dictionary:
 return {"format":"journey/1","act":1,"step":"opening","story_index":0,"clues":[],"motives":[],"visited":{},"insight":0,"completed":[],"upgrades":{},"marks":[],"mark":"","letters":{},"known_blanks":{},"hint":false,"assist":false,"unlocked":1,"rehearsal_index":0,"finished":false,"elapsed_seconds":0.0}

static func valid(data: Dictionary) -> bool:
 if not data.get("journey") is Dictionary: return false
 var d: Dictionary=data.journey
 if d.get("format","")!="journey/1": return false
 for key in ["act","story_index","insight","unlocked","rehearsal_index","elapsed_seconds"]:
  if not (d.get(key) is int or d.get(key) is float) or not is_finite(float(d[key])) or float(d[key])<0: return false
 for key in ["act","story_index","insight","unlocked","rehearsal_index"]:
  if float(d[key])!=floor(float(d[key])): return false
 if int(d.act) not in [1,2,3] or int(d.unlocked) not in [1,2,3] or int(d.rehearsal_index)>1 or int(d.story_index)>20: return false
 if not d.get("step") is String or d.step not in ["opening","duel","after_tutorial","investigation","rehearsals","rehearsal","fork","road","curtain","letter","dream","shop","ending","playbill"]: return false
 for key in ["clues","motives","completed","marks"]:
  if not d.get(key) is Array: return false
  for value in d[key]:
   if not value is String: return false
 for key in ["visited","upgrades","letters","known_blanks"]:
  if not d.get(key) is Dictionary: return false
 for key in ["hint","assist","finished"]:
  if not d.get(key) is bool: return false
 if not d.get("mark") is String or d.mark not in ["","mark.missing","mark.glow"]: return false
 for mark in d.marks:
  if mark not in ["mark.missing","mark.glow"]: return false
 for key in d.upgrades:
  if key not in ["up.reach","up.foresight","up.sturdy","up.marble"] or not (d.upgrades[key] is float or d.upgrades[key] is int): return false
  if int(d.upgrades[key])<0 or int(d.upgrades[key])>(2 if key=="up.sturdy" else 1): return false
 for value in d.visited.values():
  if not value is Array: return false
  for id in value:
   if not id is String: return false
 for value in d.known_blanks.values():
  if not value is Dictionary: return false
 for value in d.letters.values():
  if not value is Dictionary or not value.get("text") is String or not (value.get("index") is int or value.get("index") is float): return false
 if d.has("rehearsal_id") and (not d.rehearsal_id is String or not d.rehearsal_id in ["reh.rain","reh.geese","reh.cart","reh.purse","reh.key","reh.light"]): return false
 return true

static func reward(j: Dictionary, id: String) -> bool:
 if id in j.completed: return false
 j.completed.append(id); j.insight+=1
 return true

static func buy(j: Dictionary, upgrade: Dictionary) -> bool:
 var count: int=int(j.upgrades.get(upgrade.id,0))
 if count>=int(upgrade.get("limit",upgrade.get("max",1))) or int(j.insight)<int(upgrade.cost): return false
 j.insight-=int(upgrade.cost); j.upgrades[upgrade.id]=count+1
 return true

static func remember(j: Dictionary, state: Dictionary) -> void:
 j.known_blanks[state.id]=state.filled.duplicate(true)

static func normalize(data: Dictionary) -> Dictionary:
 var result: Dictionary=data.duplicate(true)
 for key in ["act","story_index","insight","unlocked","rehearsal_index"]:
  result[key]=int(result[key])
 for key in result.upgrades: result.upgrades[key]=int(result.upgrades[key])
 for value in result.letters.values(): value.index=int(value.index)
 return result
