extends Node2D
## Highlands (Level 2) — self-contained level content.
## Player, camera and inventory UI are provided by the host (test harness now,
## SceneManager later), so this scene only owns the world and its triggers.

@onready var return_area: InteractionArea = $ReturnArea

func _ready() -> void:
	if return_area:
		return_area.interact = Callable(self, "_on_leave")

func _on_leave() -> void:
	# Leave the shell and return to the main world (Level 1), dropping the
	# player at its ReturnSpawn marker. Inventory persists via player_inv.tres.
	SceneManager.exit_to("res://world/game_world.tscn", "ReturnSpawn")
