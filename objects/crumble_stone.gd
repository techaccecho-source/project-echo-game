extends Node2D
## One slab of the crumbling stretch of cliff path.
##
## Safe and unsafe slabs look identical on purpose — working out which is which
## is the whole puzzle. The bridge owns the pattern; this just knows how to sit
## in the path and how to give way, leaving a hole behind it.

signal gave_way

## Whether this one holds. Set by CrumbleBridge from its pattern.
var safe: bool = true

@onready var slab: Sprite2D = $Slab
@onready var hole: Sprite2D = $Hole

var _broken: bool = false


func _ready() -> void:
	hole.visible = false


func is_broken() -> bool:
	return _broken


## A short shudder, then the slab tips into the drop and the hole opens.
func give_way() -> void:
	if _broken:
		return
	_broken = true
	Audio.sfx("res://audio/sfx/stone_crumble.wav", -4.0, 0.10)

	var shake := create_tween()
	var x0 := slab.position.x
	for i in 3:
		shake.tween_property(slab, "position:x", x0 + 1.0, 0.04)
		shake.tween_property(slab, "position:x", x0 - 1.0, 0.04)
	shake.tween_property(slab, "position:x", x0, 0.03)
	await shake.finished

	hole.visible = true
	hole.modulate.a = 0.0
	var open := create_tween()
	open.set_parallel()
	open.tween_property(hole, "modulate:a", 1.0, 0.18)
	open.tween_property(slab, "position:y", slab.position.y + 12.0, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	open.tween_property(slab, "modulate:a", 0.0, 0.32)
	open.tween_property(slab, "scale", slab.scale * 0.8, 0.32)

	gave_way.emit()
	await open.finished
	slab.visible = false
