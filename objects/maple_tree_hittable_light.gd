class_name MapleTreeHittableLight
extends AnimatedSprite2D

@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent
@onready var collision_shape: CollisionShape2D = $TreeBody/CollisionShape

var being_hit: bool = false
var max_reached: bool = false

func _ready() -> void:
	hurt_component.hurt.connect(on_hurt)
	damage_component.max_damage_reached.connect(on_max_damage_reached)

func on_hurt(hit_damage: int) -> void:
	if being_hit || max_reached:
		return
	
	being_hit = true
	
	var new_damage = damage_component.current_damage + hit_damage
	print("new_damage: ", new_damage)
	if (new_damage >= damage_component.max_damage):
		play("trunk")
	else:
		play("shake")
	await(animation_finished)
	damage_component.apply_damage(hit_damage)
	being_hit = false

func on_max_damage_reached() -> void:
	max_reached = true
	print("max damage reached")
	collision_shape.disabled = true
