extends Control
class_name MainMenu
## The title screen — the first thing the game shows.
##
## Styled after art/branding/echo_logo.svg: a bolted wooden signboard with
## vines climbing it. Every colour here is lifted straight from that file, and
## the sign itself is that file, imported as a texture.
##
## Two things the logo does that Godot's SVG rasteriser will not: it drops
## <text> and it drops the wood-grain <pattern>. So the wordmark is re-set here
## as Labels — same monospace, same letter-spacing, same two-step shadow — and
## the grain is drawn on. Everything else (board, frame, bolts, vines, leaves,
## dots) comes from the SVG untouched.

## Where a new game begins. This was the project's main scene before the menu
## took that slot, so starting from here lands exactly where launching used to.
const NEW_GAME := "res://world/game_world.tscn"
## Level 1's own track. Audio.play_music() ignores a repeat of the same path,
## so the menu bed carries straight through into the game without restarting.
const MENU_MUSIC := "res://audio/music/hearth_hollow_bed.wav"
const SIGN := preload("res://art/branding/echo_logo.svg")
## Plays over the black between the menu and Level 1. The menu owns this rather
## than the SceneManager for the same reason game_world.gd owns the cliff one:
## which story card runs is a property of the journey, not of the transition.
const INTRO := preload("res://cutscenes/hearth_hollow_intro.tscn")

## The wordmark, as it is carved on the sign.
const TITLE := "ECHO"
const TAGLINE := "ADVENTURE AWAITS"
const HINT := "W/S or arrows to move · E or Enter to choose"

# --- the logo's palette, by its role there ---------------------------------
const NIGHT := Color("14100d")      ## ground the sign hangs against
const WOOD := Color("5c4033")       ## the board
const WOOD_LIT := Color("6b4c35")   ## the board, picked out
const GRAIN := Color("3d2817")      ## grain lines and the shallower shadow
const FRAME := Color("8b6f47")      ## the board's edging, and the three dots
const BOLT := Color("3d2817")
const BOLT_RIM := Color("2d1f12")
const CARVE := Color("2d1f12")      ## the deepest shadow under carved letters
const BONE := Color("f4e4c1")       ## the wordmark
const BONE_DIM := Color("d4b896")   ## the tagline
const VINE := Color("4a5d3f")
const LEAF := [Color("6b8e5f"), Color("7fa073"), Color("5d7051")]

# The sign is drawn on a 560x300 canvas with the board inset 28px all round;
# these keep the re-set wordmark locked to it whatever size the sign is shown.
const SIGN_ART := Vector2(560, 300)
const SIGN_W := 900.0
const SIGN_TOP := 70.0

var _buttons: Array[Button] = []
var _hint: Label
var _starting := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Audio.play_music(MENU_MUSIC, 2.0, -9.0)
	_buttons[0].grab_focus()


# --- construction -----------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.add_child(_motes())

	# Vines down both edges of the screen, so the sign's own growth looks like
	# it came from somewhere rather than being pinned on.
	var vines := VineDecor.new()
	vines.set_anchors_preset(Control.PRESET_FULL_RECT)
	vines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vines)

	var scale := SIGN_W / SIGN_ART.x
	var sign_h := SIGN_ART.y * scale
	var board := TextureRect.new()
	board.texture = SIGN
	board.set_anchors_preset(Control.PRESET_CENTER_TOP)
	board.offset_left = -SIGN_W * 0.5
	board.offset_right = SIGN_W * 0.5
	board.offset_top = SIGN_TOP
	board.offset_bottom = SIGN_TOP + sign_h
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	# The grain the SVG rasteriser threw away, put back over the board. Its
	# inner edge is the art's own 28px inset, scaled.
	var grain := SignGrain.new()
	grain.board = Rect2(
			Vector2(-SIGN_W * 0.5 + 28.0 * scale, SIGN_TOP + 28.0 * scale),
			Vector2(SIGN_W - 56.0 * scale, sign_h - 56.0 * scale))
	grain.step = 70.0 * scale
	grain.set_anchors_preset(Control.PRESET_CENTER_TOP)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grain)

	# The wordmark, back on the board. Offsets are the SVG's own, scaled: the
	# title sits at (280,152) on the art, the tagline at (280,227).
	_carved(TITLE, 80.0 * scale, 12.0 * scale, SIGN_TOP + 152.0 * scale,
			BONE, 6.0 * scale, 3.0 * scale)
	_carved(TAGLINE, 12.0 * scale, 4.5 * scale, SIGN_TOP + 227.0 * scale,
			BONE_DIM, 1.0 * scale, 0.0)

	var menu := VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER_TOP)
	menu.offset_left = -260
	menu.offset_right = 260
	menu.offset_top = SIGN_TOP + sign_h + 70.0
	menu.add_theme_constant_override("separation", 18)
	add_child(menu)

	menu.add_child(_button("Start game", _on_start))
	menu.add_child(_button("Load game", _on_unbuilt.bind("Load game")))
	menu.add_child(_button("Settings", _on_unbuilt.bind("Settings")))

	# Grain and bolts go over the planks, not under them — they are marks on
	# the wood's surface, and a Button's own stylebox would bury them.
	var detail := PlankDetail.new()
	detail.planks = _buttons
	detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail)

	_hint = _label(HINT, 18, FRAME)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -128
	_hint.offset_bottom = -92
	add_child(_hint)

	var credit := _label("Team Echo", 18, WOOD_LIT)
	credit.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -68
	credit.offset_bottom = -32
	add_child(credit)


## One line of the wordmark: two offset shadow copies under a bone face, which
## is how the letters read as cut into the board rather than printed on it.
func _carved(text: String, size: float, spacing: float, mid_y: float,
		face: Color, deep: float, shallow: float) -> void:
	var font := _mono(size, spacing)
	var layers: Array = [[CARVE, deep]]
	if shallow > 0.0:
		layers.append([GRAIN, shallow])
	layers.append([face, 0.0])
	for layer in layers:
		var l := _label(text, int(size), layer[0])
		l.add_theme_font_override("font", font)
		l.set_anchors_preset(Control.PRESET_CENTER_TOP)
		l.offset_left = -SIGN_W * 0.5 + layer[1]
		l.offset_right = SIGN_W * 0.5 + layer[1]
		l.offset_top = mid_y - size + layer[1]
		l.offset_bottom = mid_y + size + layer[1]
		add_child(l)


## Bold monospace with the logo's letter-spacing. Taken from the system rather
## than bundled: the pack ships no font, and this is the one screen that wants
## a typeface at all.
func _mono(size: float, spacing: float) -> FontVariation:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray([
		"Menlo", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
	sys.font_weight = 700
	var fv := FontVariation.new()
	fv.base_font = sys
	fv.spacing_glyph = int(spacing)
	# The last glyph's trailing space would pull the line off centre.
	fv.variation_embolden = 0.02
	return fv


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", BONE_DIM)
	b.add_theme_color_override("font_hover_color", BONE)
	b.add_theme_color_override("font_focus_color", BONE)
	b.add_theme_color_override("font_pressed_color", BONE)
	# A dark outline is what makes the label read as cut into the plank.
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", CARVE)
	b.add_theme_stylebox_override("normal", _plank(WOOD, GRAIN))
	b.add_theme_stylebox_override("hover", _plank(WOOD_LIT, FRAME))
	b.add_theme_stylebox_override("focus", _plank(WOOD_LIT, FRAME))
	b.add_theme_stylebox_override("pressed", _plank(GRAIN, FRAME))
	b.pressed.connect(pressed)
	# Pointer and keyboard drive the same highlight, so the two never disagree
	# about which plank is selected.
	b.mouse_entered.connect(b.grab_focus)
	_buttons.append(b)
	return b


func _plank(fill: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Warm specks drifting through the dark, in place of the grey mist the
## cutscenes use — this screen is woodland, not weather.
func _motes() -> CPUParticles2D:
	var m := CPUParticles2D.new()
	m.amount = 26
	m.lifetime = 16.0
	m.preprocess = 16.0
	m.local_coords = false
	m.position = Vector2(960, 560)
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.emission_rect_extents = Vector2(1000, 560)
	m.direction = Vector2(-0.3, -1)
	m.gravity = Vector2.ZERO
	m.spread = 24.0
	m.initial_velocity_min = 4.0
	m.initial_velocity_max = 14.0
	m.scale_amount_min = 0.5
	m.scale_amount_max = 1.6
	m.color = Color(0.85, 0.72, 0.45, 0.16)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	m.texture = t
	return m


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# The game moves on WASD and acts on E; the menu should answer to the same
	# keys, not just to the engine's default arrows and Enter.
	if _starting or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("up"):
		_step_focus(-1)
	elif event.is_action("down"):
		_step_focus(1)
	elif event.is_action("interact"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused:
			focused.emit_signal("pressed")
	else:
		return
	get_viewport().set_input_as_handled()


func _step_focus(dir: int) -> void:
	var at := _buttons.find(get_viewport().gui_get_focus_owner())
	_buttons[wrapi(at + dir, 0, _buttons.size())].grab_focus()


# --- actions ----------------------------------------------------------------

func _on_start() -> void:
	if _starting:
		return
	_starting = true
	_hint.text = ""
	SceneManager.start_game(NEW_GAME, INTRO)


func _on_unbuilt(what: String) -> void:
	_hint.text = "%s is not available yet." % what
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(func() -> void: _hint.text = HINT)


# --- decoration -------------------------------------------------------------

## The signboard's wood grain. Godot's SVG rasteriser drops the logo's <pattern>
## element, so the same three leaning lines are repeated here by hand, at the
## widths and opacities the pattern uses.
class SignGrain extends Control:
	## In this node's own space: x is measured from the horizontal centre.
	var board := Rect2()
	var step := 112.0

	func _draw() -> void:
		var runs: Array = [[8.0, 6.0, 1.5, 0.15], [30.0, 33.0, 1.0, 0.10],
				[52.0, 49.0, 2.0, 0.08]]
		var x := board.position.x
		while x < board.end.x:
			for r: Array in runs:
				var top: float = x + step * (r[0] / 70.0)
				var bot: float = x + step * (r[1] / 70.0)
				if top < board.position.x or top > board.end.x:
					continue
				draw_line(Vector2(top, board.position.y),
						Vector2(bot, board.end.y),
						Color(MainMenu.GRAIN, r[3]), r[2])
			x += step


## Grain lines and corner bolts, drawn over the menu planks. Kept as its own
## node so it sits above the Buttons in the draw order.
class PlankDetail extends Control:
	var planks: Array[Button] = []

	func _draw() -> void:
		for b in planks:
			var r := Rect2(b.global_position, b.size)
			# Three lines with a slight lean, the same figure as the logo's
			# wood-grain pattern.
			for i in 3:
				var x := r.position.x + r.size.x * (0.18 + 0.3 * i)
				draw_line(Vector2(x, r.position.y + 5),
						Vector2(x - 3 + i * 3, r.end.y - 5),
						Color(MainMenu.GRAIN, 0.35), 1.0 + i * 0.5)
			for side in [0.0, 1.0]:
				var c := Vector2(lerpf(r.position.x + 18, r.end.x - 18, side),
						r.position.y + r.size.y * 0.5)
				draw_circle(c, 5.0, MainMenu.BOLT)
				draw_arc(c, 5.0, 0.0, TAU, 16, MainMenu.BOLT_RIM, 2.0)
				draw_circle(c + Vector2(-1, -1), 1.5,
						Color(MainMenu.WOOD_LIT, 0.5))

	func _process(_delta: float) -> void:
		queue_redraw()


## Vines climbing the left and right edges of the screen. Built from the same
## parts as the logo's — a leaning stem, short branchlets, ellipse leaves — and
## given the same slow rock, pivoting where the vine leaves the top of frame.
class VineDecor extends Control:
	const SWAY := deg_to_rad(2.5)   ## the whole vine, as in the logo
	const LEAF_SWAY := deg_to_rad(14.0)

	class Leaf:
		var at: Vector2
		var rx: float
		var ry: float
		var rot: float
		var tint: Color
		var speed: float
		var phase: float

	var _stems: Array = []          ## Array[PackedVector2Array]
	var _twigs: Array = []          ## Array of [from, to]
	var _leaves: Array[Leaf] = []
	var _pivots: Array[Vector2] = []
	var _t := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260910
		for side in [-1.0, 1.0]:
			var x0: float = 58.0 if side < 0.0 else 1862.0
			_pivots.append(Vector2(x0, -40.0))
			var stem := PackedVector2Array()
			var y := -40.0
			while y < 1140.0:
				stem.append(Vector2(x0 + sin(y * 0.0075) * 13.0 * side, y))
				y += 26.0
			_stems.append(stem)
			# Branchlets and leaves alternate which way they reach, so the vine
			# never looks combed to one side.
			var out := 1.0
			y = 30.0
			while y < 1110.0:
				var base := Vector2(x0 + sin(y * 0.0075) * 13.0 * side, y)
				var reach: float = rng.randf_range(26.0, 46.0) * out * side
				var tip := base + Vector2(reach, rng.randf_range(-6.0, 6.0))
				_twigs.append([base, tip])
				var lf := Leaf.new()
				lf.at = tip + Vector2(reach * 0.28, 0.0)
				lf.rx = rng.randf_range(11.0, 16.0)
				lf.ry = rng.randf_range(6.5, 9.5)
				lf.rot = deg_to_rad(rng.randf_range(-46.0, 46.0))
				lf.tint = MainMenu.LEAF[rng.randi() % MainMenu.LEAF.size()]
				lf.speed = rng.randf_range(2.4, 3.7)
				lf.phase = rng.randf() * TAU
				_leaves.append(lf)
				out = -out
				y += rng.randf_range(74.0, 108.0)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _rock(p: Vector2, pivot: Vector2, angle: float) -> Vector2:
		return pivot + (p - pivot).rotated(angle)

	func _draw() -> void:
		for i in _stems.size():
			var pivot: Vector2 = _pivots[i]
			var angle: float = sin(_t / (4.2 + i * 0.4) * TAU) * SWAY
			var stem: PackedVector2Array = _stems[i]
			var swung := PackedVector2Array()
			for p in stem:
				swung.append(_rock(p, pivot, angle))
			draw_polyline(swung, MainMenu.VINE, 5.0, true)
		# Twigs and leaves belong to whichever vine they grew from: left half of
		# the screen to the left stem, right half to the right.
		for tw in _twigs:
			var i := 0 if tw[0].x < 960.0 else 1
			var angle: float = sin(_t / (4.2 + i * 0.4) * TAU) * SWAY
			draw_line(_rock(tw[0], _pivots[i], angle),
					_rock(tw[1], _pivots[i], angle), MainMenu.VINE, 3.0, true)
		for lf in _leaves:
			var i := 0 if lf.at.x < 960.0 else 1
			var angle: float = sin(_t / (4.2 + i * 0.4) * TAU) * SWAY
			var at := _rock(lf.at, _pivots[i], angle)
			var spin := lf.rot + angle + sin(_t / lf.speed * TAU + lf.phase) * LEAF_SWAY
			draw_colored_polygon(_ellipse(at, lf.rx, lf.ry, spin), lf.tint)

	func _ellipse(at: Vector2, rx: float, ry: float, rot: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(at + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
		return pts
