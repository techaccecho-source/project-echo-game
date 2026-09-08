extends CharacterBody2D

## Emitted the moment the player goes under, before the level reloads.
signal drowned

const SPLASH := preload("res://objects/water_splash.tscn")
const FALL_TIME := 0.6
const SINK_TIME := 0.5

@export var inv: Inv
@export var walk_speed: float = 100
@export var run_speed: float = 200
@export var character_name: String = "Player"
@onready var hit_component_collision_shape: CollisionShape2D = $HitComponent/HitComponentCollisionShape2D

@onready var animated_sprite = $Movement

# Track last direction so idle plays the correct facing animation
var last_direction: Vector2 = Vector2(0, 1) # default face down
var movement_enabled: bool = true

var is_dying: bool = false
var is_chopping: bool = true

func _ready() -> void:
	hit_component_collision_shape.disabled = true
	hit_component_collision_shape.position = Vector2(0, 0)

func _physics_process(_delta):
	if (!movement_enabled):
		return
	var input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()
	
	var is_running = Input.is_action_pressed("run")
	var current_speed = run_speed if is_running else walk_speed
	
	velocity = input_direction * current_speed
	move_and_slide()
	
	if input_direction != Vector2.ZERO:
		last_direction = input_direction
	
	if Input.is_action_just_pressed("interact_alt"):
		play_weapon_logic()
		return
	
	update_animation(input_direction, is_running)

func update_animation(input_direction: Vector2, is_running: bool):
	var state = "idle"
	var dir = last_direction # use last known direction when idle
	
	if input_direction != Vector2.ZERO:
		dir = input_direction
		state = "run" if is_running else "walk"
		
	# Pick dominant axis for the direction suffix
	var anim_suffix = get_direction_suffix(dir)
	
	animated_sprite.play(state + "_" + anim_suffix)

func get_direction_suffix(dir: Vector2) -> String:
	# Flip sprite for left, use right animation
	if abs(dir.x) > abs(dir.y):
		# Horizontal movement is dominant
		if dir.x > 0:
			animated_sprite.flip_h = false
			return "right"
		else:
			animated_sprite.flip_h = true
			return "right"
	else:
		# Vertical movement is dominant
		animated_sprite.flip_h = false
		if dir.y < 0:
			return "up"
		else:
			return "down"

func play_weapon_logic():
		disable_movement()
		hit_component_collision_shape.disabled = false
		animated_sprite.play("axe_swing_" + get_direction_suffix(last_direction))
		if last_direction == Vector2.UP:
			hit_component_collision_shape.position = Vector2(-2, -11)
		if last_direction == Vector2.RIGHT:
			hit_component_collision_shape.position = Vector2(11, 4)
		if last_direction == Vector2.DOWN:
			hit_component_collision_shape.position = Vector2(2, 11)
		if last_direction == Vector2.LEFT:
			hit_component_collision_shape.position = Vector2(-11, 4)
			
		await animated_sprite.animation_finished
		hit_component_collision_shape.disabled = true
		enable_movement()

func disable_movement():
	movement_enabled = false
	
	update_animation(Vector2.ZERO, false)  # snap to idle animation immediately

func enable_movement():
	movement_enabled = true

# Inventory
# Our player has access to the inventory. This function puts an item into the inventory by calling inventory.insert
func collect(item):
	inv.insert(item)


# Falling
# Walking off an unrailed ledge drops the player into the water below. The
# player node belongs to the persistent shell rather than to the level, so it
# survives the reload in the middle of this and can put itself back together
# afterwards.
func fall_and_drown(water_y: float, respawn_scene: String, spawn: String) -> void:
	if is_dying:
		return
	is_dying = true
	movement_enabled = false
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	InteractionManager.can_interact = false
	update_animation(Vector2.ZERO, false)

	# The drop: accelerating, shrinking with distance, tipping as it goes.
	var fall = create_tween()
	fall.set_parallel()
	fall.tween_property(self, "global_position:y", water_y, FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(self, "scale", Vector2(0.55, 0.55), FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(self, "rotation_degrees", 22.0, FALL_TIME) \
		.set_trans(Tween.TRANS_SINE)
	await fall.finished

	var splash = SPLASH.instantiate()
	get_parent().add_child(splash)
	splash.global_position = Vector2(global_position.x, water_y)

	# Under.
	var sink = create_tween()
	sink.set_parallel()
	sink.tween_property(self, "global_position:y", water_y + 9.0, SINK_TIME)
	sink.tween_property(self, "scale", Vector2(0.22, 0.22), SINK_TIME)
	sink.tween_property(self, "modulate:a", 0.0, SINK_TIME)
	await sink.finished

	drowned.emit()

	if SceneManager.level_holder == null or respawn_scene == "":
		# Standalone scene (no shell): nothing persists, so a plain reload is
		# both the respawn and the cleanup — and it takes this node with it.
		get_tree().reload_current_scene()
		return

	await SceneManager.change_level(respawn_scene, spawn, _revive)
	# Cleared last, not in _revive: a fall zone re-instanced by the reload spends
	# a frame settling, and this flag is what stops it firing a second time.
	await get_tree().physics_frame
	is_dying = false


## Undo everything the death animation did. Called while the screen is black.
func _revive() -> void:
	scale = Vector2.ONE
	rotation_degrees = 0.0
	modulate.a = 1.0
	velocity = Vector2.ZERO
	last_direction = Vector2(0, 1)
	$CollisionShape2D.set_deferred("disabled", false)
	InteractionManager.can_interact = true
	movement_enabled = true
	update_animation(Vector2.ZERO, false)
