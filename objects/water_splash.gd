extends Node2D
## A short bubble burst where something went into the water, then it cleans
## itself up. Purely cosmetic — nothing waits on it.

const LIFETIME := 1.5

func _ready() -> void:
	var burst: AnimatedSprite2D = $Burst
	burst.play("splash")
	# Two more, smaller and late, so the surface keeps moving for a beat after
	# the first ring rather than snapping still.
	for i in 2:
		var extra := burst.duplicate() as AnimatedSprite2D
		extra.position = Vector2(-8.0 + i * 15.0, 2.0 + i * 3.0)
		var s := 0.7 - i * 0.15
		extra.scale = Vector2(s, s)
		extra.visible = false
		add_child(extra)
		await get_tree().create_timer(0.14 + i * 0.12).timeout
		if not is_instance_valid(extra):
			return
		extra.visible = true
		extra.play("splash")
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()
