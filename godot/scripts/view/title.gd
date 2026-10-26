extends Control
const Catalog = preload("res://scripts/services/asset_catalog.gd")
const Sounds = preload("res://scripts/services/audio_service.gd")
var catalog := Catalog.new()
var sounds := Sounds.new()
var cupper := Sprite2D.new()
var time := 0.0
var click_count := 0
var cup_timer := Timer.new()
var status: Label
var text: Dictionary
var pixel_font: FontFile
var closing := false
var idle_animation: Dictionary = {}

func _ready() -> void:
 get_tree().auto_accept_quit = false
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 text = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/title.json"))
 pixel_font = load("res://resources/fonts/fusion-pixel-12px/switcheroo-pixel-12.ttf") as FontFile
 pixel_font.antialiasing = 0
 pixel_font.hinting = 0
 pixel_font.subpixel_positioning = 0
 var theme_data := Theme.new()
 theme_data.default_font = pixel_font
 theme_data.default_font_size = 12
 theme = theme_data
 var backdrop := TextureRect.new()
 backdrop.texture = catalog.texture("stage.frame")
 backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
 backdrop.size = Vector2(640, 360)
 add_child(backdrop)
 add_child(sounds)
 sounds.setup(catalog)
 cup_timer.one_shot = true
 cup_timer.timeout.connect(_lift_cups)
 add_child(cup_timer)
 _label(str(text.chapter), Rect2(140, 66, 360, 18), 12, "#eec05a")
 _label(str(text.title), Rect2(140, 88, 360, 32), 24, "#fff0a8")
 _label(str(text.subtitle), Rect2(140, 126, 360, 18), 12, "#efe2c4")
 cupper.texture = catalog.texture("char.cupper")
 cupper.hframes = int(catalog.art("char.cupper").frames)
 idle_animation = catalog.art("char.cupper").animations.idle
 cupper.position = Vector2(320, 219)
 cupper.scale = Vector2(2, 2)
 add_child(cupper)
 _label("杯戏师", Rect2(264, 158, 112, 18), 12, "#efe2c4")
 _button(str(text.action), Rect2(200, 300, 120, 24), _try_cups)
 _button("敲锣", Rect2(328, 300, 112, 24), _try_gong)
 status = _label(str(text.status), Rect2(136, 326, 368, 18), 12, "#efe2c4")
 if "--shots" in OS.get_cmdline_user_args():
  _capture()

func _label(value: String, box: Rect2, font_size: int, color: String) -> Label:
 var label := Label.new()
 label.text = value
 label.position = box.position
 label.size = box.size
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", Color(color))
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(label)
 label.size = box.size
 return label

func _button(value: String, box: Rect2, callback: Callable) -> void:
 var button := Button.new()
 button.text = value
 button.add_theme_font_size_override("font_size", 12)
 button.position = box.position
 button.size = box.size
 button.add_theme_color_override("font_color", Color("#fff0a8"))
 for state: String in ["normal", "hover", "pressed", "focus"]:
  var style := StyleBoxFlat.new()
  style.bg_color = Color("#7a1a2c") if state in ["hover", "focus"] else Color("#4a0f1e")
  style.border_color = Color("#eec05a")
  style.set_border_width_all(1)
  button.add_theme_stylebox_override(state, style)
 button.pressed.connect(callback)
 add_child(button)
 button.size = box.size

func _enable_sound() -> void:
 if not sounds.enabled:
  sounds.unlock()
  sounds.music("music.d0_theme")

func _try_cups() -> void:
 _enable_sound()
 click_count += 1
 sounds.play("sfx.cup_down")
 status.text = "扣杯……"
 cup_timer.start(0.18)

func _lift_cups() -> void:
 sounds.play("sfx.cup_up")
 status.text = "掀杯！这次听见了吗？" if sounds.output_available else "掀杯！当前为静音预览。"

func _try_gong() -> void:
 cup_timer.stop()
 _enable_sound()
 sounds.play("sting.exposed")
 status.text = "锣声响，下一出等你来。" if sounds.output_available else "锣声已加载（静音预览）"

func _process(delta: float) -> void:
 time += delta
 if not idle_animation.is_empty():
  var sequence: Array = idle_animation.frames
  cupper.frame = int(sequence[int(time * float(idle_animation.fps)) % sequence.size()])
 cupper.position.y = 219 + round(sin(time * 2.0) * 2.0)

func _capture() -> void:
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var image := get_viewport().get_texture().get_image()
 var base := ProjectSettings.globalize_path("res://../artifacts/screenshots")
 DirAccess.make_dir_recursive_absolute(base)
 image.save_png(base + "/d0-title-1x.png")
 image.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
 image.save_png(base + "/d0-title-3x.png")
 print("D0 title captures saved to artifacts/screenshots/")
 await get_tree().create_timer(0.4).timeout
 get_tree().quit()

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
  _close_cleanly()

func _close_cleanly() -> void:
 closing = true
 cup_timer.stop()
 sounds.stop_all()
 await get_tree().process_frame
 await get_tree().process_frame
 get_tree().quit()
