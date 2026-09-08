extends CanvasLayer

# Letters used for the QTE, minus anything already bound to movement/interaction
# (W, A, S, D, E, I, B, T) so the prompt never collides with normal controls.
const LETTER_POOL := "CFGHJKLMNOPQRUVXYZ"

const LETTER_DURATION := 0.8
const FEEDBACK_DURATION := 0.55
const PRE_COUNTDOWN_PAUSE := 0.35
const COUNTDOWN_STEP := 0.55
const GO_HOLD := 0.45
const POST_LETTERS_PAUSE := 0.4
const BLANK_TRANSITION := 0.15
const RESULT_HOLD := 1.1
const PANEL_FADE := 0.2

const LETTER_FONT_SIZE := 64
const RESULT_FONT_SIZE := 26

const COLOR_NEUTRAL := Color(0, 0, 0, 1)
const COLOR_HIT := Color(0.14117648, 0.44705883, 0.14117648, 1)
const COLOR_MISS := Color(0.68235296, 0.14117648, 0.09803922, 1)
const COLOR_GO := Color(0.7137255, 0.4745098, 0.043137256, 1)

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var main_label: Label = $Panel/Margin/VBox/MainLabel

var waiting_letter: String = ""
var hit_this_letter: bool = false

func _ready() -> void:
	panel.visible = false
	panel.modulate.a = 0.0
	main_label.pivot_offset = main_label.custom_minimum_size / 2

func _unhandled_input(event: InputEvent) -> void:
	if waiting_letter == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if char(event.unicode).to_upper() == waiting_letter:
			hit_this_letter = true

# Shows a "get ready" countdown, then `length` random letters one at a time.
# Each must be pressed within LETTER_DURATION seconds to count as a hit.
# Finishes with a standalone result screen (never overlapping the last
# letter). Returns true only if every letter in the sequence was hit.
func play_sequence(length: int = 3) -> bool:
	await _show_panel()
	await _play_countdown()

	var all_hit = true
	title_label.text = "PRESS IT!"

	for i in range(length):
		var letter = LETTER_POOL[randi() % LETTER_POOL.length()]
		waiting_letter = letter
		hit_this_letter = false
		_pop_main_text(letter, COLOR_NEUTRAL, LETTER_FONT_SIZE)

		var elapsed = 0.0
		while elapsed < LETTER_DURATION and not hit_this_letter:
			await get_tree().process_frame
			elapsed += get_process_delta_time()

		waiting_letter = ""
		main_label.add_theme_color_override("font_color", COLOR_HIT if hit_this_letter else COLOR_MISS)
		if not hit_this_letter:
			all_hit = false

		await get_tree().create_timer(FEEDBACK_DURATION).timeout

	await get_tree().create_timer(POST_LETTERS_PAUSE).timeout

	# Clear the last letter first so the result reads on its own, not layered on top of it.
	title_label.text = ""
	main_label.text = ""
	await get_tree().create_timer(BLANK_TRANSITION).timeout

	_pop_main_text(
		"YOU CAUGHT IT!" if all_hit else "IT GOT AWAY...",
		COLOR_HIT if all_hit else COLOR_MISS,
		RESULT_FONT_SIZE
	)
	await get_tree().create_timer(RESULT_HOLD).timeout

	await _hide_panel()
	return all_hit

# "Fishing starting in 3.. 2.. 1.. GO!" beat before the letters start,
# so the player has a clear, unhurried signal that the QTE is about to begin.
func _play_countdown() -> void:
	title_label.text = "GET READY"
	await get_tree().create_timer(PRE_COUNTDOWN_PAUSE).timeout
	for step in ["3", "2", "1"]:
		_pop_main_text(step, COLOR_GO, LETTER_FONT_SIZE)
		await get_tree().create_timer(COUNTDOWN_STEP).timeout
	_pop_main_text("GO!", COLOR_HIT, LETTER_FONT_SIZE)
	await get_tree().create_timer(GO_HOLD).timeout

# Sets the main label's text/color/size and punches it in with a little
# scale-up bounce, so each beat (countdown tick, letter, result) feels like
# an event instead of a hard instant swap.
func _pop_main_text(text: String, color: Color, font_size: int) -> void:
	main_label.text = text
	main_label.add_theme_color_override("font_color", color)
	main_label.add_theme_font_size_override("font_size", font_size)
	main_label.scale = Vector2(0.65, 0.65)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(main_label, "scale", Vector2.ONE, 0.18)

func _show_panel() -> void:
	panel.visible = true
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, PANEL_FADE)
	await tween.finished

func _hide_panel() -> void:
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, PANEL_FADE)
	await tween.finished
	panel.visible = false
