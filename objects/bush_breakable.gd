class_name BushBreakable
extends AnimatedSprite2D

@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent
@onready var collision_shape: CollisionShape2D = $Body/Rectangle
@onready var ground_mark: Sprite2D = $OpenGround

var being_hit: bool = false
var max_reached: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hurt_component.hurt.connect(on_hurt)
	damage_component.max_damage_reached.connect(on_max_damage_reached)
	ground_mark.visible = false
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func on_hurt(hit_damage: int) -> void:
	if (being_hit || max_reached):
		return
	
	being_hit = true
	
	var new_damage = damage_component.current_damage + hit_damage
	if (new_damage >= damage_component.max_damage):
		play("removed")
	else:
		play("shake")
	await(animation_finished)
	damage_component.apply_damage(hit_damage)
	being_hit = false

func on_max_damage_reached() -> void:
	max_reached = true
	collision_shape.disabled = true
	ground_mark.visible = true
