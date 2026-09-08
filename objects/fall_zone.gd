extends Area2D
## The drop where a ledge has no railing and no floor below it.
##
## Pair it with a gap in the level's TerrainCollision: the collision gap is what
## lets the player walk off, and this is what catches them once they have. Cover
## the whole gap — anything the player can reach in there should be in here, or
## they fall into empty space forever.

## Size of the trigger box, in pixels. Built in code so a level generator can
## bake one number instead of overriding a shared sub-resource.
@export var size: Vector2 = Vector2(144, 248)
## World Y of the water surface — where the fall ends and the splash plays.
@export var water_y: float = 200.0
## Level to reload once they drown.
@export_file("*.tscn") var respawn_scene: String = "res://world/game_level_2.tscn"
## Marker2D in that level's "player_spawn" group to put them back at.
@export var respawn_spawn: String = "Entrance"


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)

	# A respawn reloads the level, which drops a fresh copy of this zone into the
	# world while the player is still lying where they fell — SceneManager adds
	# the level first and moves the player to their spawn second. Monitoring from
	# frame one would see a body already inside and fire the fall again. Wait for
	# the level to settle, by which time the player is long gone to their spawn.
	monitoring = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree():
		set_deferred("monitoring", true)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("fall_and_drown"):
		return
	# Deliberately not awaited: this zone dies with the level partway through,
	# and the player — who lives in the shell — owns the rest of the sequence.
	body.fall_and_drown(water_y, respawn_scene, respawn_spawn)
