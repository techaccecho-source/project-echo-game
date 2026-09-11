extends AnimatedSprite2D
## A rowing boat riding at anchor out in the bay.
##
## The pack's four frames already animate the ripple around the hull; this adds
## the slow lift of the swell under it, and a little yaw, so it never sits
## perfectly still.

## Pixels the hull rises and falls.
@export var bob := 1.5
## Seconds for one rise and fall.
@export var period := 4.5
## Degrees the bow swings either side of centre.
@export var yaw := 1.5

var _phase := 0.0
var _rest := 0.0

func _ready() -> void:
	_rest = position.y
	_phase = randf() * TAU
	frame = randi() % maxi(1, sprite_frames.get_frame_count(animation)) if sprite_frames else 0
	speed_scale = randf_range(0.7, 1.0)
	play()

func _process(delta: float) -> void:
	_phase += delta * TAU / maxf(0.1, period)
	position.y = _rest + sin(_phase) * bob
	rotation_degrees = sin(_phase * 0.61) * yaw
