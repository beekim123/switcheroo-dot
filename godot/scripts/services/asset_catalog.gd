extends RefCounted
var _art: Dictionary = {}
var _audio: Dictionary = {}

func _init() -> void:
 for entry: Dictionary in _read("res://resources/art/manifest.json").get("assets", []):
  _art[entry.id] = entry
 for entry: Dictionary in _read("res://resources/audio/manifest.json").get("assets", []):
  _audio[entry.id] = entry

func _read(path: String) -> Dictionary:
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
 return parsed if parsed is Dictionary else {}

func art(id: String) -> Dictionary:
 return _art.get(id, {})

func texture(id: String) -> Texture2D:
 assert(_art.has(id), "Unknown art id " + id)
 return load("res://resources/art/" + str(_art[id].file)) as Texture2D

func sound(id: String) -> AudioStream:
 assert(_audio.has(id), "Unknown audio id " + id)
 var stream: AudioStreamWAV = load("res://resources/audio/" + str(_audio[id].file)) as AudioStreamWAV
 if bool(_audio[id].get("loop", false)):
  stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
  stream.loop_begin = 0
  stream.loop_end = int(float(_audio[id].seconds) * float(_audio[id].sample_rate))
 return stream
