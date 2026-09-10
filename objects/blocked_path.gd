extends Node2D
## The old road out of Hearth Hollow, barricaded and signed.
##
## Narrative signpost rather than a puzzle: it shows the player that there was
## a way out here, that it was deliberately closed, and that they will have to
## find another. The three notches under the sign's last line are the
## Forester's mark — the same one on his cache and his staff.
##
## Self-contained: it brings its own strip of path, so it can be dropped
## anywhere without editing a level's hand-authored terrain layers.

@export var sign_title: String = "sign"
@export var barricade_title: String = "barricade"

@onready var sign_area: InteractionArea = $SignArea
@onready var barricade_area: InteractionArea = $BarricadeArea

var dialogue_resource = load("res://dialogue/old_path.dialogue")
var player: CharacterBody2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	sign_area.interact = Callable(self, "_read_sign")
	barricade_area.interact = Callable(self, "_inspect_barricade")


func _read_sign() -> void:
	_say(sign_title)


func _inspect_barricade() -> void:
	_say(barricade_title)


func _say(title: String) -> void:
	if dialogue_resource == null:
		# A .dialogue only becomes loadable once Dialogue Manager has imported
		# it, so a fresh file is null until the editor has been focused once.
		push_warning("blocked_path: dialogue/old_path.dialogue has not been imported yet.")
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	DialogueManager.show_dialogue_balloon(dialogue_resource, title, [self, player])
