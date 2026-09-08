extends Node2D
## A page of Cedric's blog lying in the world.
##
## Point it at a Fragment resource and drop it into a level — it removes itself
## if that fragment is already recovered, so re-entering a level never offers
## the same page twice.
##
## Picking one up puts it in the player's inventory; reading it happens there
## (click the page in the bag) or with [J]. EchoLog handles both.

## The page this pickup hands over.
@export var fragment: Fragment

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: Sprite2D = $Glow
@onready var interaction_area: InteractionArea = $InteractionArea

var _taken: bool = false


func _ready() -> void:
	if fragment == null:
		push_warning("FragmentPickup at %s has no fragment assigned." % global_position)
		return
	if EchoLog.has_fragment(fragment.id):
		queue_free()
		return
	interaction_area.interact = Callable(self, "_on_interact")
	_bob()


## Slow float, so a 16px page still reads as "pick me up" against busy ground.
func _bob() -> void:
	var base := sprite.position.y
	var t := create_tween().set_loops()
	t.tween_property(sprite, "position:y", base - 3.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sprite, "position:y", base, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var g := create_tween().set_loops()
	g.tween_property(glow, "modulate:a", 0.55, 1.6).set_trans(Tween.TRANS_SINE)
	g.tween_property(glow, "modulate:a", 0.15, 1.6).set_trans(Tween.TRANS_SINE)


func _on_interact() -> void:
	if _taken:
		return
	_taken = true
	interaction_area.queue_free()

	var t := create_tween().set_parallel()
	t.tween_property(sprite, "position:y", sprite.position.y - 10.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.45)
	await t.finished

	EchoLog.collect(fragment)
	queue_free()
