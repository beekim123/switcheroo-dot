extends Node
var catalog: RefCounted
var enabled := false
var output_available := false
var _effects: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _cursor := 0
var _active_music := 0
var _duck_timer := Timer.new()

func setup(assets: RefCounted) -> void:
 catalog = assets
 output_available = AudioServer.get_driver_name() != "Dummy"
 _duck_timer.one_shot = true
 _duck_timer.timeout.connect(_restore_music)
 add_child(_duck_timer)
 for bus: String in ["Music", "SFX"]:
  if AudioServer.get_bus_index(bus) < 0:
   AudioServer.add_bus()
   AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
 var limiter := AudioEffectLimiter.new()
 limiter.ceiling_db = -1.0
 AudioServer.add_bus_effect(0, limiter)
 for i in range(6):
  var player := AudioStreamPlayer.new()
  player.bus = "SFX"
  add_child(player)
  _effects.append(player)
 for i in range(2):
  var player := AudioStreamPlayer.new()
  player.bus = "Music"
  add_child(player)
  _music.append(player)

func unlock() -> void:
 enabled = true

func play(id: String) -> void:
 if not enabled:
  return
 var player := _effects[_cursor % _effects.size()]
 _cursor += 1
 player.stream = catalog.sound(id)
 if output_available:
  player.play()
 if id == "sting.exposed":
  AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -12.0)
  _duck_timer.start(0.8)

func music(id: String) -> void:
 if not enabled:
  return
 var old := _music[_active_music]
 _active_music = 1 - _active_music
 var current := _music[_active_music]
 current.stream = catalog.sound(id)
 current.volume_db = -40.0
 if output_available:
  current.play()
 var tween := create_tween().set_parallel(true)
 tween.tween_property(current, "volume_db", -3.0, 0.6)
 tween.tween_property(old, "volume_db", -40.0, 0.6)
 tween.chain().tween_callback(old.stop)

func _restore_music() -> void:
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 0.0)

func stop_all() -> void:
 _duck_timer.stop()
 for player: AudioStreamPlayer in _effects + _music:
  player.stop()
  player.stream = null

func _exit_tree() -> void:
 stop_all()
 catalog = null
