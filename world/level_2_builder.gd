@tool
extends Node2D
## Cliffside Path terrain builder (Level 2).
##
## Paints the Water / Cliffs / Ground TileMapLayers, rebuilds the terrain
## collision and scatters the wall-side pines, all from the ledge profile below.
## It is a *bake* tool, not a runtime system: tick "Build Terrain" in the
## inspector, the cells are written into the scene, and from then on you can
## hand-edit them like any other painted layer. Nothing runs at game time.
##
## The tileset (base_terrain/grass_and_cliff_and_water.tres) has no terrain
## sets configured, so tiles are placed by explicit atlas coordinate. The
## coordinates below match the ones already in use elsewhere in the project.

const SRC_CLIFF := 7
const SRC_WATER := 3

# --- tiles, source 7 (Tileset Grass Cliff Tileset Spring) -------------------
const T_GRASS  := Vector2i(9, 2)   ## plain interior grass
const T_UP     := Vector2i(6, 0)   ## grass with the dark fringe, sits under a wall
const T_DOWN   := Vector2i(6, 3)   ## grass at the lip of a drop
const T_LEFT   := Vector2i(4, 2)
const T_RIGHT  := Vector2i(8, 2)
const T_TL     := Vector2i(4, 0)
const T_TR     := Vector2i(8, 0)
const T_BL     := Vector2i(4, 3)
const T_BR     := Vector2i(8, 3)
const T_FACE   := Vector2i(9, 4)   ## rock wall body
const T_WATER  := Vector2i(0, 0)   ## source 3, single sea tile

@export_group("Actions")
## Tick to repaint everything from the profile below.
@export var build_terrain: bool = false:
	set(v):
		build_terrain = false
		if v and is_inside_tree():
			_build()
## Tick to wipe the generated layers, collision and props.
@export var clear_terrain: bool = false:
	set(v):
		clear_terrain = false
		if v and is_inside_tree():
			_clear()

@export_group("Shape")
@export var level_width: int = 80
@export var level_height: int = 26
## How many rows of rock face hang below the ledge before the sea.
@export var cliff_depth: int = 2
## Ledge profile control points: x = column, y = first grass row,
## z = last grass row. Values are interpolated between consecutive points, so
## two points one column apart give a hard step (that is how the collapsed
## span at x=24..25 is made).
@export var ledge_profile: Array[Vector3i] = [
	Vector3i(0, 8, 15),
	Vector3i(10, 8, 14),
	Vector3i(18, 8, 13),
	Vector3i(24, 8, 12),
	Vector3i(25, 8, 9),    # abrupt: the span fell away
	Vector3i(33, 8, 9),    # the squeeze
	Vector3i(34, 7, 12),   # abrupt: ledge resumes
	Vector3i(42, 7, 16),
	Vector3i(50, 7, 17),   # camp shelf, widest point
	Vector3i(58, 7, 16),
	Vector3i(64, 6, 15),
	Vector3i(72, 6, 14),
	Vector3i(79, 7, 14),
]

@export_group("Props")
@export var place_props: bool = true
@export var pine_scene: PackedScene = preload("res://objects/pine_tree_large.tscn")
## Columns between pines along the base of the mountain wall.
@export var pine_spacing: int = 6
## Columns to leave bare (the collapsed span), as [from, to] inclusive.
@export var pine_skip_from: int = 24
@export var pine_skip_to: int = 34

var _top: PackedInt32Array
var _bot: PackedInt32Array


# --- profile ---------------------------------------------------------------

func _resolve_profile() -> void:
	_top = PackedInt32Array()
	_bot = PackedInt32Array()
	_top.resize(level_width)
	_bot.resize(level_width)
	if ledge_profile.size() < 2:
		push_warning("level_2_builder: ledge_profile needs at least two points.")
		return
	for i in ledge_profile.size() - 1:
		var a := ledge_profile[i]
		var b := ledge_profile[i + 1]
		for x in range(a.x, min(b.x, level_width)):
			var f := 0.0 if b.x == a.x else float(x - a.x) / float(b.x - a.x)
			_top[x] = int(round(lerp(float(a.y), float(b.y), f)))
			_bot[x] = int(round(lerp(float(a.z), float(b.z), f)))
	var last := ledge_profile[ledge_profile.size() - 1]
	for x in range(last.x, level_width):
		_top[x] = last.y
		_bot[x] = last.z


func _is_grass(x: int, y: int) -> bool:
	if x < 0 or x >= level_width:
		return false
	return y >= _top[x] and y <= _bot[x]


## Picks the grass tile for a cell from which of its four neighbours are open.
func _grass_tile(x: int, y: int) -> Vector2i:
	var up := not _is_grass(x, y - 1)
	var down := not _is_grass(x, y + 1)
	var left := not _is_grass(x - 1, y)
	var right := not _is_grass(x + 1, y)
	if up and left: return T_TL
	if up and right: return T_TR
	if down and left: return T_BL
	if down and right: return T_BR
	if up: return T_UP
	if down: return T_DOWN
	if left: return T_LEFT
	if right: return T_RIGHT
	return T_GRASS


# --- build / clear ---------------------------------------------------------

func _layer(n: String) -> TileMapLayer:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null(n) as TileMapLayer


func _clear() -> void:
	for n in ["Water", "Cliffs", "Ground"]:
		var l := _layer(n)
		if l:
			l.clear()
	var parent := get_parent()
	if parent:
		for holder_name in ["TerrainCollision", "Props"]:
			var holder := parent.get_node_or_null(holder_name)
			if holder == null:
				continue
			# Immediate removal, not queue_free(), so the rebuild below does not
			# briefly run alongside the previous generation.
			for c in holder.get_children():
				holder.remove_child(c)
				c.free()


func _build() -> void:
	var parent := get_parent()
	if parent == null:
		push_warning("level_2_builder: needs to be a child of the level root.")
		return
	var water := _layer("Water")
	var cliffs := _layer("Cliffs")
	var ground := _layer("Ground")
	if water == null or cliffs == null or ground == null:
		push_warning("level_2_builder: expected sibling TileMapLayers named Water, Cliffs and Ground.")
		return

	_resolve_profile()
	_clear()

	for x in level_width:
		for y in level_height:
			water.set_cell(Vector2i(x, y), SRC_WATER, T_WATER)
		for y in range(0, _top[x]):
			cliffs.set_cell(Vector2i(x, y), SRC_CLIFF, T_FACE)
		for y in range(_bot[x] + 1, min(_bot[x] + 1 + cliff_depth, level_height)):
			cliffs.set_cell(Vector2i(x, y), SRC_CLIFF, T_FACE)
		for y in range(_top[x], _bot[x] + 1):
			ground.set_cell(Vector2i(x, y), SRC_CLIFF, _grass_tile(x, y))

	_build_collision(parent)
	if place_props:
		_build_props(parent)


## One rectangle per run of columns that share a height, for the mountain above
## the ledge and the drop below it.
func _build_collision(parent: Node) -> void:
	var body := parent.get_node_or_null("TerrainCollision") as StaticBody2D
	if body == null:
		push_warning("level_2_builder: no TerrainCollision StaticBody2D found; skipping collision.")
		return
	var owner_node := get_tree().edited_scene_root if Engine.is_editor_hint() else parent

	var x := 0
	while x < level_width:
		var e := x
		while e + 1 < level_width and _top[e + 1] == _top[x]:
			e += 1
		if _top[x] > 0:
			_add_rect(body, owner_node, "mtn_%d" % x,
				(e - x + 1) * 16, _top[x] * 16,
				x * 16 + (e - x + 1) * 8, _top[x] * 8)
		x = e + 1

	x = 0
	while x < level_width:
		var e2 := x
		while e2 + 1 < level_width and _bot[e2 + 1] == _bot[x]:
			e2 += 1
		var h := (level_height - 1 - _bot[x]) * 16
		if h > 0:
			_add_rect(body, owner_node, "drop_%d" % x,
				(e2 - x + 1) * 16, h,
				x * 16 + (e2 - x + 1) * 8, (_bot[x] + 1) * 16 + h / 2.0)
		x = e2 + 1


func _add_rect(body: StaticBody2D, owner_node: Node, n: String,
		w: float, h: float, cx: float, cy: float) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var cs := CollisionShape2D.new()
	cs.name = n
	cs.shape = shape
	cs.position = Vector2(cx, cy)
	body.add_child(cs)
	if owner_node:
		cs.owner = owner_node


func _build_props(parent: Node) -> void:
	var props := parent.get_node_or_null("Props") as Node2D
	if props == null or pine_scene == null:
		return
	var owner_node := get_tree().edited_scene_root if Engine.is_editor_hint() else parent
	var i := 0
	for x in range(2, level_width - 2, max(1, pine_spacing)):
		if x >= pine_skip_from and x <= pine_skip_to:
			continue
		var pine := pine_scene.instantiate() as Node2D
		pine.name = "Pine%d" % i
		pine.position = Vector2(x * 16 + 8, _top[x] * 16 + 14)
		pine.z_index = 5
		props.add_child(pine)
		if owner_node:
			pine.owner = owner_node
		i += 1
