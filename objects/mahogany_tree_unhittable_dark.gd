class_name MahoganyTreeUnhittableDark
extends AnimatedSprite2D

@onready var hurt_component: HurtComponent = $HurtComponent

func _ready() -> void:
	hurt_component.hurt.connect(on_hurt)

func on_hurt(hit_damage: int) -> void:
	play("shake")
	
