extends CharacterBody2D
## The Forester (Level 2 — the Cliffside Path).
##
## He is stationary by design: he waits at his camp facing the path, because
## the beat is that he has been expecting whoever finally got through. The
## reveal itself lives in dialogue/forester.dialogue; this script only owns the
## interaction and the talking state the dialogue toggles.

@export var character_name: String = "Forester"

@onready var animated_sprite: AnimatedSprite2D = $Movement
@onready var interaction_area: InteractionArea = $InteractionArea

var dialogue_resource = load("res://dialogue/forester.dialogue")
var player: CharacterBody2D
var talking: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	interaction_area.interact = Callable(self, "_on_interact")
	animated_sprite.play("idle_down")


func _on_interact() -> void:
	if talking:
		return
	DialogueManager.show_dialogue_balloon(dialogue_resource, "start", [self, player])


# --- called from the dialogue --------------------------------------------

func start_talking() -> void:
	talking = true


func stop_talking() -> void:
	talking = false


func _on_dialogue_ended(_resource) -> void:
	talking = false
	if player:
		player.enable_movement()
