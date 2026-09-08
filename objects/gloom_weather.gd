extends Node2D
class_name GloomWeather
## Overcast, windy weather for an outdoor level.
##
## Three parts, all built in code so there are no hand-authored particle
## resources to drift out of sync with the level:
##   * a CanvasModulate that cools and darkens the whole 2D world (the HUD and
##     the Echo Log live on their own CanvasLayers, so they are untouched);
##   * fast thin streaks blowing across, which is what actually reads as wind;
##   * a few slow, large, very faint mist patches for depth.
##
## CPUParticles2D rather than GPUParticles2D on purpose: every knob lives on the
## node instead of a separate process material, so this stays one readable file.

## Cool grey-blue the world is tinted with. White = no tint.
@export var tint: Color = Color(0.62, 0.68, 0.80):
	set(v):
		tint = v
		if _modulate:
			_modulate.color = v
## Area the weather covers, in pixels. Should be the whole level plus a margin.
@export var area_size: Vector2 = Vector2(1500, 560)
## Centre of that area, in level coordinates.
@export var area_center: Vector2 = Vector2(640, 208)
## Which way the wind pushes. Length is ignored; only the direction is used.
@export var wind: Vector2 = Vector2(-1.0, 0.22)
@export_range(0, 200) var streak_count: int = 52
## Thin mist drifting over the whole level.
@export_range(0, 120) var mist_count: int = 34
## Extra dense banks, in level coordinates — the cliff faces and the tree line,
## where mist actually collects. Each rect gets its own slower, fatter emitter.
@export var mist_bands: Array[Rect2] = []
@export_range(0, 120) var band_mist_count: int = 26
## Turn the tint off but keep the wind, e.g. for a level that sets its own mood.
@export var tint_world: bool = true

var _modulate: CanvasModulate
var _streaks: CPUParticles2D
var _mist: CPUParticles2D


func _ready() -> void:
	if tint_world:
		_modulate = CanvasModulate.new()
		_modulate.color = tint
		add_child(_modulate)
	_streaks = _make_streaks()
	add_child(_streaks)
	_mist = _make_mist()
	add_child(_mist)
	for band in mist_bands:
		add_child(_make_band(band))


## Thin, bright, mostly transparent — a gust you notice at the edge of vision.
func _make_streaks() -> CPUParticles2D:
	var p := _base_emitter(streak_count, 2.6)
	p.z_index = 20
	p.texture = _streak_texture()
	p.initial_velocity_min = 130.0
	p.initial_velocity_max = 260.0
	p.spread = 5.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.color = Color(0.88, 0.93, 1.0, 0.26)
	return p


## Big, slow, barely there. Sits under the wind but over the terrain.
func _make_mist() -> CPUParticles2D:
	var p := _base_emitter(mist_count, 13.0)
	p.z_index = 15
	p.texture = _mist_texture()
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 24.0
	p.spread = 22.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.5
	p.color = Color(0.82, 0.87, 0.94, 0.14)
	return p


## A bank clinging to one stretch — the cliff face, or the treeline at the foot
## of the wall. Slower, fatter and thicker than the drifting mist, and it fades
## in and out rather than streaming past.
func _make_band(band: Rect2) -> CPUParticles2D:
	var p := _base_emitter(band_mist_count, 16.0)
	p.z_index = 14
	p.texture = _mist_texture()
	p.position = band.position + band.size * 0.5
	p.emission_rect_extents = band.size * 0.5
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.spread = 10.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color = Color(0.84, 0.89, 0.95, 0.19)
	# Swell and thin out, so the bank breathes instead of sliding.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.35, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 0.9))
	p.color_ramp = ramp
	return p


func _base_emitter(amount: int, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = maxi(1, amount)
	p.lifetime = life
	# Run the simulation forward before the first frame, so the level opens
	# mid-gust instead of with the wind visibly starting up.
	p.preprocess = life
	p.local_coords = false
	p.position = area_center
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area_size * 0.5
	p.direction = wind.normalized()
	p.gravity = Vector2.ZERO
	p.damping_min = 0.0
	p.damping_max = 6.0
	p.angle_min = rad_to_deg(wind.angle())
	p.angle_max = rad_to_deg(wind.angle())
	return p


## Transparent -> white -> transparent along its length: a short streak.
func _streak_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 1))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 22
	t.height = 2
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	return t


## Soft round blob.
func _mist_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 48
	t.height = 48
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
