class_name FishingSpot
extends Node2D

@export var fish_pool: Array[InvItem] = []
@export var min_wait_time: float = 0.8
@export var max_wait_time: float = 1.8

@onready var interaction_area: InteractionArea = $InteractionArea

var player: CharacterBody2D
var busy: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact() -> void:
	if busy or player == null:
		return
	busy = true
	var face_direction = (global_position - player.global_position).normalized()
	await player.catch_fish(fish_pool, face_direction, min_wait_time, max_wait_time)
	busy = false
