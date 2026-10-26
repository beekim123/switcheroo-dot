extends RefCounted

static func tutorial(turn: int) -> String:
 if turn==1: return "月屑就在旁边，先出手。杯戏师还不听话！"
 if turn==2: return "接住杯子！两只都瞄着槽 3，把月屑换过去？"
 return "意图锁定站位。换过去，让它打到自己。"
