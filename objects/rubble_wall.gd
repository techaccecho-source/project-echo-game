extends Node2D
## Rubble wall (Level 2) — stone and vine piled across the way to the cave.
##
## This branch has no damage/tool component system, so clearing it is a single
## interaction gated on carrying the axe, rather than repeated hits. If the
## component system from `dev` lands here later, this is the piece to swap for
## a HurtComponent so it matches the Level 1 trees.

signal cleared

## Item the player must be carrying to clear this. Leave null to allow anyone.
@export var required_item: InvItem
@export var blocked_title: String = "blocked"
@export var cleared_title: String = "cleared"

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var body: StaticBody2D = $Body
@onready var body_shape: CollisionShape2D = $Body/CollisionShape2D
@onready var rubble: Node2D = $Rubble

var dialogue_resource = load("res://dialogue/rubble_wall.dialogue")
var player: CharacterBody2D
var is_cleared: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	interaction_area.interact = Callable(self, "_on_interact")
	_refresh_prompt()


## The prompt doubles as the hint: "clear" only shows once you have the axe.
func _refresh_prompt() -> void:
	interaction_area.action_name = "clear" if _player_has_tool() else "inspect"


func _player_has_tool() -> bool:
	if required_item == null:
		return true
	if player == null or player.inv == null:
		return false
	return player.inv.has(required_item)


func _on_interact() -> void:
	if is_cleared:
		return
	if not _player_has_tool():
		DialogueManager.show_dialogue_balloon(dialogue_resource, blocked_title, [self, player])
		_refresh_prompt()
		return
	is_cleared = true
	DialogueManager.show_dialogue_balloon(dialogue_resource, cleared_title, [self, player])
	_break_apart()


func _break_apart() -> void:
	InteractionManager.deregister_area(interaction_area)
	interaction_area.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	var t := create_tween()
	t.tween_property(rubble, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(rubble, "position", rubble.position + Vector2(0, 3), 0.35)
	await t.finished
	rubble.visible = false
	cleared.emit()
