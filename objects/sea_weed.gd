extends Sprite2D
## A clump of seaweed clinging to a rock in the sea.
##
## The sprite's origin is at the base of the clump (see the scene's `offset`),
## so skewing it bends the fronds sideways while the roots stay put. Pick which
## clump you get with `region_rect`; the pack's sheet has two shapes, each in a
## bright and a submerged tint.

## How far the fronds lean at the extremes, in radians.
@export var sway := 0.14
## Seconds for one full there-and-back sway.
@export var period := 3.4

var _phase := 0.0

func _ready() -> void:
	# Desync, or a whole reef of weed leans in unison.
	_phase = randf() * TAU
	period *= randf_range(0.8, 1.25)

func _process(delta: float) -> void:
	_phase += delta * TAU / maxf(0.1, period)
	skew = sin(_phase) * sway
