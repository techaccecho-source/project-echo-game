extends Node2D
## Surf washing out from the foot of the cliff.
##
## The baked waterline tiles already carry a static foam lip and its shadow;
## this draws the moving part below them — a band of foam that swells out into
## the sea and pulls back, travelling along the shore so no two stretches
## breathe together. Drawn by hand rather than animated with tiles: the pack's
## animated shore tiles are all sand-to-water, and this shore is rock.

## One entry per 16px column of shore: x is its left edge, y the first row of
## open water under it, both in world pixels. Baked by scratchpad/gen_level2.py.
@export var columns: PackedVector2Array

## How far the foam reaches out from the rock, in pixels.
@export var swell := 4.0
## Radians per second of the swell.
@export var speed := 1.1
## Pixels between one crest and the next.
@export var wavelength := 96.0
## Redraw rate. Deliberately low: chunky steps suit the art, and it keeps the
## whole shore down to a few redraws' worth of work a second.
@export var fps := 12.0

## The pack's own foam colours, lifted from the waterline tile.
const FOAM := Color("52d0f1")
const CREST := Color("8dfdff")

var _t := 0.0
var _frame := -1

func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * fps)
	if f != _frame:
		_frame = f
		queue_redraw()

func _height(px: float) -> int:
	# Biased so the trough sits below zero: the foam surges in patches with
	# clear water between them, rather than ringing the whole shore at once.
	var phase := _t * speed - px * TAU / maxf(1.0, wavelength)
	var v := sin(phase) * 0.62 + sin(phase * 0.43 + px * 0.055) * 0.38
	return maxi(0, int(round((v - 0.18) * swell)))

func _draw() -> void:
	for c in columns:
		# Runs of equal height become one rect each, or a shore this long is
		# a couple of thousand draw calls a frame.
		var run_x := c.x
		var run_h := _height(c.x)
		for i in range(1, 17):
			var h := _height(c.x + i) if i < 16 else -1
			if h == run_h:
				continue
			if run_h > 0:
				var w := c.x + i - run_x
				# A single row is just a ripple; only a real surge catches the
				# light along its leading edge.
				draw_rect(Rect2(run_x, c.y, w, 1.0),
						CREST if run_h > 1 else FOAM)
				if run_h > 1:
					draw_rect(Rect2(run_x, c.y + 1.0, w, run_h - 1), FOAM)
			run_x = c.x + i
			run_h = h
