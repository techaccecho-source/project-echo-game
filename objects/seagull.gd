extends AnimatedSprite2D
class_name Seagull
## A gull, either wheeling over the sea or sitting on it.
##
## The sheet has both: rows 0-4 are the bird in the air, rows 5-7 the same bird
## with a strip of water baked in under its feet. The floating ones matter most
## — the sea is a single flat colour with no animation of its own, so they are
## the only thing actually moving on it.

enum Mode { FLYING, FLOATING }

@export var mode: Mode = Mode.FLOATING
## Pixels per second along the drift.
@export var speed: float = 26.0
## How far it wanders either side of where it was placed.
@export var travel: float = 260.0
## Vertical bob for a floating bird.
@export var bob: float = 1.6

var _home: Vector2
var _t: float = 0.0
var _flap_at: float = 0.0


func _ready() -> void:
	_home = position
	# Desync everything, or a flock beats its wings in unison.
	_t = randf() * TAU
	speed_scale = randf_range(0.75, 1.25)
	_flap_at = 4.0 + randf() * 6.0
	if mode == Mode.FLYING:
		play("fly")
	else:
		play("float")


func _process(delta: float) -> void:
	_t += delta
	if mode == Mode.FLYING:
		var phase := _t * speed / maxf(travel, 1.0)
		position = _home + Vector2(sin(phase) * travel, sin(_t * 0.55) * 7.0)
		# The art faces left, so flip when heading the other way.
		flip_h = cos(phase) > 0.0
		return

	position = _home + Vector2(0.0, sin(_t * 1.3) * bob)
	# Every so often it stretches its wings, then settles again.
	if _t >= _flap_at:
		_flap_at = _t + 5.0 + randf() * 7.0
		play("flap")
		await animation_looped
		if is_instance_valid(self) and mode == Mode.FLOATING:
			play("float")
