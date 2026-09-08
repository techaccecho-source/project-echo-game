extends Node
## Global scene/level manager (autoload "SceneManager").
##
## Two kinds of transition:
##   • change_level()  — swaps the level *inside the persistent shell* (game.tscn).
##                       The player, camera and inventory UI are kept alive, so
##                       this is a seamless swap with no reload. Use it between
##                       shell levels (Level 2, 3, ...).
##   • enter_shell() / exit_to() — full scene changes, used to move between the
##                       legacy standalone world (Level 1 / game_world.tscn) and
##                       the shell. Inventory still carries over because it lives
##                       in the shared player_inv.tres resource.
##
## Spawn placement: every level exposes one or more Marker2D nodes in the
## "player_spawn" group. Pass the marker name to drop the player there.

const SHELL_PATH := "res://world/game.tscn"
const FADE_TIME := 0.35

## Persistent references, registered by the shell (game.gd) while it is active.
var player: Node2D = null
var level_holder: Node2D = null

## Pending target used across a full scene change.
var _next_level_path: String = "res://world/game_level_2.tscn"
var _next_spawn: String = ""
## True while a transition is in flight, so a freshly loaded scene knows it
## should place the player at the pending spawn (instead of its authored start).
var incoming: bool = false

var _fade: ColorRect


func _ready() -> void:
	_build_fade_overlay()


func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _fade_to(alpha: float) -> void:
	var t := get_tree().create_tween()
	t.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await t.finished


# --- Entering / leaving the persistent shell -------------------------------

## Enter the shell from a standalone scene, loading `level_path` and placing the
## player at `spawn`.
func enter_shell(level_path: String, spawn: String = "") -> void:
	_next_level_path = level_path
	_next_spawn = spawn
	incoming = true
	await _fade_to(1.0)
	get_tree().change_scene_to_file(SHELL_PATH)


## Called by the shell (game.gd) once its holder and player exist.
func register_shell(holder: Node2D, shell_player: Node2D) -> void:
	level_holder = holder
	player = shell_player
	_load_into_holder(_next_level_path, _next_spawn)
	incoming = false
	await _fade_to(0.0)


## Leave the shell for a standalone scene (e.g. the legacy Level 1 world).
func exit_to(scene_path: String, spawn: String = "") -> void:
	_next_spawn = spawn
	incoming = true
	level_holder = null
	player = null
	await _fade_to(1.0)
	get_tree().change_scene_to_file(scene_path)


## Called from a standalone scene's _ready to finish an incoming transition:
## places the player at the pending spawn and fades back in.
func on_standalone_ready() -> void:
	if not incoming:
		return
	player = get_tree().get_first_node_in_group("player")
	_place_player(_next_spawn)
	incoming = false
	await _fade_to(0.0)


# --- Swapping levels inside the shell --------------------------------------

## Swap the level currently inside the shell. Player/camera/UI stay alive.
##
## `on_loaded` runs after the new level is in and the player placed, but before
## the screen fades back in — the only safe moment to fix up anything the player
## is carrying across the swap (a death animation's scale/rotation/alpha, say).
func change_level(level_path: String, spawn: String = "",
		on_loaded: Callable = Callable()) -> void:
	if level_holder == null:
		push_warning("SceneManager.change_level() called while not in the shell.")
		return
	await _fade_to(1.0)
	_load_into_holder(level_path, spawn)
	if on_loaded.is_valid():
		on_loaded.call()
	await _fade_to(0.0)


func _load_into_holder(level_path: String, spawn: String) -> void:
	for child in level_holder.get_children():
		child.queue_free()
	var level := (load(level_path) as PackedScene).instantiate()
	level_holder.add_child(level)
	_place_player(spawn)


# --- Helpers ----------------------------------------------------------------

func _place_player(spawn: String) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var marker := _find_spawn(spawn)
	if marker:
		player.global_position = marker.global_position


func _find_spawn(spawn: String) -> Node2D:
	var markers := get_tree().get_nodes_in_group("player_spawn")
	if spawn != "":
		for m in markers:
			if m.name == spawn:
				return m as Node2D
	if markers.size() > 0:
		return markers[0] as Node2D
	return null
