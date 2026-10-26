extends RefCounted
const Rehearsal = preload("res://scripts/core/rehearsal.gd")
const Duel = preload("res://scripts/core/duel_rules.gd")

static func solve(definition: Dictionary, journey: Dictionary={}) -> Array:
 var s: Dictionary=Rehearsal.start(definition,journey)
 var solutions: Array=[]
 _visit(s,[],solutions)
 return solutions

static func _visit(s: Dictionary, path: Array, solutions: Array) -> void:
 var finish: Dictionary=s.duplicate(true)
 if Rehearsal.perform(finish): solutions.append(path.duplicate(true))
 if path.size()>=int(s.swap_limit)+1: return
 for action in Duel.legal_actions(s):
  if action.kind=="swap" and action.mode!=s.definition.get("mode","position"): continue
  var copy: Dictionary=s.duplicate(true)
  Duel.command(copy,action)
  var next: Array=path.duplicate(true); next.append(action)
  _visit(copy,next,solutions)
