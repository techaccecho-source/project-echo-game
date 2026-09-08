extends Node2D
## The cave mouth at the east end of the Cliffside Path.
##
## This is the hand-off to Case 03. That level does not exist yet, so until it
## does the cave plays a holding line instead of transitioning — set
## `target_scene` and it starts working with no other changes.

## Level to move to. Ignored while the file does not exist.
@export_file("*.tscn") var target_scene: String = "res://world/game_level_3.tscn"
## Marker2D name in the target level's "player_spawn" group.
@export var target_spawn: String = ""
## Optional rubble wall that must be cleared first.
@export var rubble_path: NodePath

@onready var interaction_area: InteractionArea = $InteractionArea

var dialogue_resource = load("res://dialogue/cave_entrance.dialogue")
var player: CharacterBody2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	interaction_area.interact = Callable(self, "_on_interact")


func _blocked_by_rubble() -> bool:
	if rubble_path.is_empty():
		return false
	var r := get_node_or_null(rubble_path)
	if r == null:
		return false
	return not r.is_cleared


func _on_interact() -> void:
	# Reachable but still blocked: say so rather than doing nothing, otherwise
	# pressing interact just looks broken.
	if _blocked_by_rubble():
		DialogueManager.show_dialogue_balloon(dialogue_resource, "rubble", [self, player])
		return
	if target_scene != "" and ResourceLoader.exists(target_scene):
		DialogueManager.show_dialogue_balloon(dialogue_resource, "enter", [self, player])
		await DialogueManager.dialogue_ended
		SceneManager.change_level(target_scene, target_spawn)
	else:
		DialogueManager.show_dialogue_balloon(dialogue_resource, "sealed", [self, player])
