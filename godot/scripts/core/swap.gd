extends RefCounted
const Stage = preload("res://scripts/core/stage_state.gd")

static func can(s: Dictionary, mode: String, a: int, b: int) -> Dictionary:
 var reason := ""
 if s.outcome != "": reason="这出戏已经结束"
 elif s.rule=="prologue" and s.turn==1: reason="还没有接住杯子"
 elif int(s.swap_used)>=int(s.swap_limit): reason="本回合已经交换过了"
 elif a<0 or b<0 or a>=5 or b>=5 or a==b: reason="请选择两个不同站位"
 elif Stage.hidden(s,a) or Stage.hidden(s,b): reason="看不见他"
 elif mode=="item":
  if not s.item_unlocked: reason="第三出才学会换物"
  elif s.slots[a]==null or s.slots[b]==null or s.slots[a].get("item","")=="" or s.slots[b].get("item","")=="": reason="两边都要拿着东西"
 elif mode=="position":
  if absi(a-b)>int(s.reach): reason="距离超过 "+str(s.reach)
  elif s.slots[a]==null and s.slots[b]==null: reason="不能交换两个空站位"
  else:
   for i in [a,b]:
    if s.slots[i]!=null and s.slots[i].get("heavy",false): reason="太重了，换不动"
 else: reason="未知形态"
 return {"ok":reason=="","reason":reason}

static func apply(s: Dictionary, mode: String, a: int, b: int) -> Dictionary:
 var valid := can(s,mode,a,b)
 if not valid.ok: return valid
 if mode=="position":
  var old: Variant=s.slots[a]; s.slots[a]=s.slots[b]; s.slots[b]=old
 else:
  var old: String=s.slots[a].item; s.slots[a].item=s.slots[b].item; s.slots[b].item=old
 s.swap_used+=1
 if s.mark=="mark.glow":
  for i in [a,b]:
   if s.slots[i]!=null: s.slots[i].glow_until=s.turn
 if s.mark=="mark.missing" and mode=="position":
  for i in [a,b]:
   if s.slots[i]!=null and s.slots[i].kind=="prop" and absi(i-Stage.player_slot(s))==1: s.slots[i].protect_until=s.turn
 Stage.emit(s,{"type":"swap","mode":mode,"a":a,"b":b})
 return valid
