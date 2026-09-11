extends Node2D
class_name CrumbleBridge
## A crumbling stretch of cliff path where only one lane per step holds.
##
## The path widens here and is paved with slabs. The player crosses left to
## right; at each step exactly one lane holds, and the rest tip into the drop
## and take the player down the cliff into the sea far below. Safe and unsafe stones
## are visually identical, so the crossing is learnt by dying — which means the
## respawn wants to be the near side of the bridge, not the far side of the
## level. Set `respawn_spawn` to a marker just before it.
##
## The pattern is written the way a level designer reads it, one string per
## lane, left to right:
##     "X O X X X"
##     "O X O O X"
##     "X X X X O"
## O = holds, X = gives way. Whitespace is ignored. Every column needs exactly
## one O or the crossing is impossible (or free), which _ready() checks for.
##
## Occupancy is decided by polling the player's centre against the grid rather
## than by per-stone Area2Ds: the stones sit edge to edge, so overlapping areas
## would fire two triggers at once on the boundary between them.

const STONE := preload("res://objects/crumble_stone.tscn")
## Paving-slab variants in Exterior/Road.png, all single 16x16 tiles.
const SLABS: Array[Rect2] = [
	Rect2(0, 112, 16, 16), Rect2(16, 112, 16, 16), Rect2(32, 112, 16, 16),
	Rect2(0, 128, 16, 16), Rect2(16, 128, 16, 16),
]

## Top-left corner of the grid, in tiles.
@export var origin_tile: Vector2i = Vector2i(26, 9)
## Size of one panel, in tiles. The paving slabs are a single 16x16 tile.
@export var cell_tiles: Vector2i = Vector2i(1, 1)
## One line per lane; see the class docs.
@export var pattern: Array[String] = [
	"X O X X X",
	"O X O O X",
	"X X X X O",
]
## How far inside a panel the player's centre must be before it counts as
## stepped on, in pixels. Stops a clipped corner reading as a commitment.
## Panels are only 16px, so this has to stay small.
@export var edge_forgiveness: float = 2.5

@export_group("Falling")
## World Y of the sea at the foot of the cliff. The player drops through the
## hole and lands down there, not at path level.
@export var sea_y: float = 320.0
@export_file("*.tscn") var respawn_scene: String = "res://world/game_level_2.tscn"
@export var respawn_spawn: String = "BridgeApproach"

var _safe: Array[Array] = []        ## _safe[lane][step]
var _stones: Array[Array] = []      ## _stones[lane][step]
var _steps: int = 0
var _lanes: int = 0
var _cell: Vector2 = Vector2(32, 32)
var _current := Vector2i(-1, -1)
var _falling: bool = false
var _player: Node2D


func _ready() -> void:
	_cell = Vector2(cell_tiles) * 16.0
	_parse_pattern()
	if _steps == 0:
		return
	_build_stones()
	_player = get_tree().get_first_node_in_group("player")


func _parse_pattern() -> void:
	_safe.clear()
	for line in pattern:
		var row: Array[bool] = []
		for ch in line:
			if ch == "O" or ch == "o":
				row.append(true)
			elif ch == "X" or ch == "x":
				row.append(false)
		_safe.append(row)
	_lanes = _safe.size()
	_steps = 0
	for row in _safe:
		_steps = maxi(_steps, row.size())
	# Pad ragged lines rather than letting them index out of range later.
	for row in _safe:
		while row.size() < _steps:
			row.append(false)
	for s in _steps:
		var holds := 0
		for l in _lanes:
			if _safe[l][s]:
				holds += 1
		if holds != 1:
			push_warning("CrumbleBridge: step %d has %d safe lanes, expected exactly 1." % [s, holds])


func _build_stones() -> void:
	var base := Vector2(origin_tile) * 16.0
	for l in _lanes:
		var row: Array[Node] = []
		for s in _steps:
			var stone := STONE.instantiate()
			stone.safe = _safe[l][s]
			# Vary the slab art. Deliberately uncorrelated with safe/unsafe:
			# a tell here would give the puzzle away.
			var slab := stone.get_node_or_null("Slab") as Sprite2D
			if slab:
				var v: int = abs(int(origin_tile.x) * 7 + s * 5 + l * 3) % SLABS.size()
				slab.region_rect = SLABS[v]
			# Centre of the panel; the sprite is centred.
			stone.position = base + Vector2(s + 0.5, l + 0.5) * _cell
			add_child(stone)
			row.append(stone)
		_stones.append(row)


## Which panel the point is on, or (-1,-1) for none / too close to an edge.
func _cell_at(p: Vector2) -> Vector2i:
	var local := p - Vector2(origin_tile) * 16.0
	var s := int(floor(local.x / _cell.x))
	var l := int(floor(local.y / _cell.y))
	if s < 0 or s >= _steps or l < 0 or l >= _lanes:
		return Vector2i(-1, -1)
	var inset := Vector2(local.x - s * _cell.x, local.y - l * _cell.y)
	if inset.x < edge_forgiveness or inset.x > _cell.x - edge_forgiveness:
		return Vector2i(-1, -1)
	if inset.y < edge_forgiveness or inset.y > _cell.y - edge_forgiveness:
		return Vector2i(-1, -1)
	return Vector2i(s, l)


func _physics_process(_delta: float) -> void:
	if _falling or _steps == 0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var c := _cell_at(_player.global_position)
	if c == _current:
		return
	_current = c
	if c.x < 0:
		return
	if _safe[c.y][c.x]:
		return
	_give_way(c)


func _give_way(c: Vector2i) -> void:
	_falling = true
	var stone: Node = _stones[c.y][c.x]
	if stone and stone.has_method("give_way"):
		stone.give_way()
		# Let the shudder play out before the player goes with it.
		await stone.gave_way
	if _player and _player.has_method("fall_through_and_drown"):
		_player.fall_through_and_drown(sea_y, respawn_scene, respawn_spawn)
