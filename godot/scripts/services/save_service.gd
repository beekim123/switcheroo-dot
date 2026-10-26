extends RefCounted
const SAVE_PATH := "user://save.json"
const VERSION := 1

func store(data: Dictionary) -> Error:
 var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
 if file == null:
  return FileAccess.get_open_error()
 file.store_string(JSON.stringify({"version": VERSION, "data": data}))
 file.close()
 return DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)

func restore() -> Dictionary:
 if not FileAccess.file_exists(SAVE_PATH):
  return {}
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
 if not parsed is Dictionary or parsed.get("version") != VERSION or not parsed.get("data") is Dictionary:
  DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".corrupt-" + str(Time.get_ticks_usec()))
  return {}
 return parsed.data
