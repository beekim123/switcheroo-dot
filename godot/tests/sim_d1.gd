extends SceneTree
const DB = preload("res://scripts/content/content_db.gd")
const Bots = preload("res://scripts/core/bots.gd")
const Duel = preload("res://scripts/core/duel_rules.gd")
const Solver = preload("res://scripts/core/solver.gd")

func _initialize() -> void:
 var db := DB.new()
 var report: Dictionary={"format":"d1-simulation/1","deterministic":true,"note":"Each unique authored starting state is deterministic, not a statistical sample of human play. Cautious disables all signboard rewards and uses position swaps only to dodge.","runs":[],"rehearsals":[]}
 var failed := false
 for definition in db.all("duels"):
  for strategy in ["cautious","lookahead","no_swap"]:
   var run: Dictionary=Bots.play(definition,strategy)
   var expected: String=JSON.stringify(run.state).sha256_text()
   var replays := 0
   for attempt in range(20):
    var replay: Dictionary=Duel.start(definition,{"blanks_disabled":strategy=="cautious"})
    for row in run.commands:
     for command in row.plan:
      Duel.command(replay,command)
      if replay.outcome!="": break
     if replay.outcome=="": Duel.end_turn(replay)
    if JSON.stringify(replay).sha256_text()==expected: replays+=1
   run.final_state_sha256=expected
   run.identical_replays=replays
   if replays!=20: failed=true
   run.erase("state")
   report.runs.append(run)
   print(definition.id," / ",strategy," win=",run.win," turns=",run.turns," hp=",run.hp," exposed=",run.exposed_turn," reversal=",run.reversal_turn," blanks=",run.blanks)
   if strategy=="cautious" and not run.win: failed=true
 for definition in db.all("rehearsals"):
  var solutions: Array=Solver.solve(definition)
  report.rehearsals.append({"id":definition.id,"solutions":solutions.size(),"first":solutions[0] if not solutions.is_empty() else []})
  print(definition.id," solutions=",solutions.size())
  if solutions.is_empty(): failed=true
 var file := FileAccess.open("res://../artifacts/reports/sim-d1.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  ")+"\n")
 file.close()
 quit(1 if failed else 0)
