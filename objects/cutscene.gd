extends CanvasLayer
class_name Cutscene
## A between-levels story card: letterboxed lines that type themselves on, then
## an optional title, then black.
##
## Data-driven so a new cutscene is a .tscn with different text and nothing
## else. Built in code for the same reason LevelAudio is — the content is the
## interesting part, the presentation should not be re-authored each time.
##
## Runs on its own CanvasLayer above everything, pauses the tree while it plays,
## and hands back on `finished`. SceneManager.play_cutscene() drives it.

signal finished

@export_multiline var beats: Array[String] = []
## Shown last, larger. Leave empty for no card.
@export var title: String = ""
@export var subtitle: String = ""

@export_group("Pacing")
## Characters per second while a line types on.
@export var type_speed: float = 46.0
## Seconds a finished line holds before it leaves.
@export var beat_hold: float = 1.5
@export var fade: float = 0.7
## Fade the current track out as the cutscene opens, so the next level's music
## arrives clean rather than cutting across.
@export var stop_music: bool = true

const INK := Color("e6dac4")
const DIM := Color("8b7f6b")
const ACCENT := Color("c9883c")

var _root: Control
var _bg: ColorRect
var _text: Label
var _title: Label
var _sub: Label
var _hint: Label
var _mist: CPUParticles2D
var _advance: bool = false
var _skip_all: bool = false
var _running: bool = false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	# One root so the whole card fades as a unit. Fading only the background
	# would let the letterbox bars snap in at full black on frame one.
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)

	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.02, 0.03, 1.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bg)

	_mist = CPUParticles2D.new()
	_mist.amount = 16
	_mist.lifetime = 12.0
	_mist.preprocess = 12.0
	_mist.local_coords = false
	_mist.position = Vector2(960, 540)
	_mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_mist.emission_rect_extents = Vector2(1200, 620)
	_mist.direction = Vector2(-1, 0.1)
	_mist.gravity = Vector2.ZERO
	_mist.spread = 20.0
	_mist.initial_velocity_min = 6.0
	_mist.initial_velocity_max = 20.0
	_mist.scale_amount_min = 3.0
	_mist.scale_amount_max = 8.0
	_mist.color = Color(0.55, 0.60, 0.70, 0.05)
	_mist.texture = _blob()
	_bg.add_child(_mist)

	# Letterbox. Thin: this is a story card, not a film.
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 84)
		bar.offset_bottom = 84 if top else 0
		bar.offset_top = 0 if top else -84
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bar)

	_text = _label(30, INK)
	_text.set_anchors_preset(Control.PRESET_CENTER)
	_text.offset_left = -560
	_text.offset_right = 560
	_text.offset_top = -70
	_text.offset_bottom = 70
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_text)

	_title = _label(52, INK)
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.offset_left = -640
	_title.offset_right = 640
	_title.offset_top = -60
	_title.offset_bottom = 10
	_title.modulate.a = 0.0
	_root.add_child(_title)

	_sub = _label(21, ACCENT)
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.offset_left = -640
	_sub.offset_right = 640
	_sub.offset_top = 16
	_sub.offset_bottom = 64
	_sub.modulate.a = 0.0
	_root.add_child(_sub)

	_hint = _label(16, DIM)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -52
	_hint.offset_bottom = -22
	_hint.text = "[Space] continue     [Esc] skip"
	_root.add_child(_hint)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _blob() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


# --- playback ---------------------------------------------------------------

## Await this. Returns once the cutscene has finished (or been skipped), with
## the screen left black so the caller can change scene without a flash.
func play() -> void:
	_running = true
	get_tree().paused = true
	if stop_music:
		Audio.stop_music(1.4)

	await _tween_to(_root, "modulate:a", 1.0, 0.5)

	for line in beats:
		if _skip_all:
			break
		await _play_line(str(line))

	if title != "" and not _skip_all:
		await _play_title()

	# Everything but the black goes; the screen is left dark so the caller can
	# change scene without the old level flashing back.
	var out := create_tween()
	out.set_parallel()
	for n in [_text, _title, _sub, _hint]:
		out.tween_property(n, "modulate:a", 0.0, fade * 0.7)
	await out.finished
	_running = false
	get_tree().paused = false
	finished.emit()


func _play_line(line: String) -> void:
	_text.text = line
	_text.visible_ratio = 0.0
	_text.modulate.a = 1.0
	_advance = false

	var duration: float = maxf(0.3, float(line.length()) / maxf(type_speed, 1.0))
	var t := create_tween()
	t.tween_property(_text, "visible_ratio", 1.0, duration)
	while t.is_running():
		if _advance or _skip_all:
			t.kill()
			_text.visible_ratio = 1.0
			_advance = false          # this press typed the line, it should not
			break                     # also dismiss it
		await get_tree().process_frame

	await _hold(beat_hold)
	if _skip_all:
		return
	await _tween_to(_text, "modulate:a", 0.0, fade * 0.6)


func _play_title() -> void:
	_advance = false
	var t := create_tween()
	t.set_parallel()
	t.tween_property(_title, "modulate:a", 1.0, 1.0)
	t.tween_property(_sub, "modulate:a", 1.0, 1.0)
	_title.text = title
	_sub.text = subtitle
	await t.finished
	await _hold(beat_hold + 0.8)


## Wait, but let a keypress cut it short.
func _hold(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _advance and not _skip_all:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_advance = false


func _tween_to(node: Object, prop: String, value: float, secs: float) -> void:
	var t := create_tween()
	t.tween_property(node, prop, value, secs)
	await t.finished


func _unhandled_input(event: InputEvent) -> void:
	if not _running or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_cancel"):
		_skip_all = true
	elif event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton:
		_advance = true
	get_viewport().set_input_as_handled()
