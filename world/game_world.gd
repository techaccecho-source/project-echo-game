extends Node2D
## Root of the legacy Level 1 world (game_world.tscn).
##
## This script only adds two things and never touches the GameLevel1 subtree:
##   • a Portal interaction that travels to the shell (Level 2), and
##   • completion of any incoming transition (placing the player at the spawn
##     the SceneManager asked for, e.g. when returning from Level 2).

@onready var portal: InteractionArea = $Portal

func _ready() -> void:
	if portal:
		portal.interact = Callable(self, "_on_portal")
	SceneManager.on_standalone_ready()

func _on_portal() -> void:
	SceneManager.enter_shell("res://world/game_level_2.tscn", "Entrance")
