extends RefCounted
var tables: Dictionary={}

func _init() -> void:
 var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/registry.json"))
 for path in registry.files:
  var parsed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+str(path)))
  for key in parsed:
   if parsed[key] is Array:
    if not tables.has(key): tables[key]=[]
    for row in parsed[key]:
     if row is Dictionary: tables[key].append(row)
   elif key!="format": tables[key]=parsed[key]

func all(table: String) -> Array:
 return tables.get(table,[])

func get_entry(id: String) -> Dictionary:
 for table in tables.values():
  if not table is Array: continue
  for row in table:
   if row is Dictionary and row.get("id","")==id: return row.duplicate(true)
 return {}
