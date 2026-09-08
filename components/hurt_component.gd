class_name HurtComponent
extends Area2D

@export var tool : DataTypes.Tools = DataTypes.Tools.NONE

signal hurt


func _on_area_entered(area: Area2D) -> void:
	var hit_component = area as HitComponent
	print("area: ", area)
	print("hit component: ", hit_component)
	if tool == hit_component.current_tool:
		print("damage taken: ", hit_component.hit_damage)
		hurt.emit(hit_component.hit_damage)
