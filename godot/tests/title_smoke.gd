extends SceneTree
var checks := 0
var failed := 0

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failed += 1
  push_error("FAIL: " + label)

func _initialize() -> void:
 _run.call_deferred()

func _run() -> void:
 var scene: Control = load("res://scenes/title.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 check(scene.idle_animation == scene.catalog.art("char.cupper").animations.idle, "animation timing and frame sequence follow manifest")
 check(scene.cupper.scale == Vector2(2, 2), "integer character scale")
 check(scene.pixel_font.get_height(12) == 12.0, "12px pixel font metrics")
 var buttons := 0
 for child: Node in scene.get_children():
  if child is Button:
   buttons += 1
   check(child.get_theme_font_size("font_size") == 12, "button pixel font size")
   check(child.size.y == 24.0 and child.position.y + child.size.y < scene.status.position.y, "button/status separation")
 check(buttons == 2, "two D0 controls")
 check(not scene.sounds.enabled, "no playback before first click")
 scene._try_cups()
 scene._try_cups()
 check(scene.sounds.enabled and scene.cup_timer.time_left > 0.0, "click unlocks and schedules cup lift")
 scene._try_gong()
 check(scene.cup_timer.is_stopped(), "new action cancels stale cup feedback")
 check(not scene.sounds.output_available, "headless Dummy is explicitly silent")
 var stream: AudioStreamWAV = scene.catalog.sound("music.d0_theme")
 check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "lossless PCM16 and forward music loop")
 stream = null
 scene.sounds.stop_all()
 print("D0 title/service checks: ", checks, "; failures: ", failed, ". Dummy driver: no audible-listening claim.")
 if failed:
  quit(1)
 else:
  scene._close_cleanly()
