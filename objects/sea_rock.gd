extends AnimatedSprite2D
## A rock standing in the sea, using the pack's own four-frame foam ring.
##
## Set `animation` to "small" (2x2 tiles) or "large" (2.5x2) on the instance.

func _ready() -> void:
	if sprite_frames == null:
		return
	# Desync, or a row of rocks pulses in unison.
	frame = randi() % maxi(1, sprite_frames.get_frame_count(animation))
	speed_scale = randf_range(0.65, 1.15)
	play()
