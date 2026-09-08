extends Node2D
## Persistent shell scene. It owns the player, camera and inventory UI, and
## hands its LevelHolder + player to the SceneManager, which streams level
## content in and out without ever reloading this scene.

func _ready() -> void:
	SceneManager.register_shell($LevelHolder, $PlayerJosh)
