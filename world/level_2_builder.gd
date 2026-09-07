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
const SRC_SOIL := 6    ## tilesets/tilled_soil_wet_soil.tres
const SRC_FALL := 0    ## water_features/spring_waterfall.tres

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
## Dry cave arch. The (13,x)..(16,x) variants have a waterline in them.
const T_CAVE_TOP := Vector2i(12, 0)
const T_CAVE_BOT := Vector2i(12, 1)

## Dirt path, side-matched autotile over source 6.
## bit 1 = north, 2 = east, 4 = south, 8 = west.
const PATH_TILES := {
	0: Vector2i(0, 3), 1: Vector2i(0, 2), 2: Vector2i(1, 3), 3: Vector2i(1, 2),
	4: Vector2i(0, 0), 5: Vector2i(0, 1), 6: Vector2i(1, 0), 7: Vector2i(1, 1),
	8: Vector2i(3, 3), 9: Vector2i(3, 2), 10: Vector2i(2, 3), 11: Vector2i(2, 2),
	12: Vector2i(3, 0), 13: Vector2i(3, 1), 14: Vector2i(2, 0), 15: Vector2i(2, 1),
}

## Scatter stamps from rock_flower_tree_grass.tres. Several are multi-tile
## pieces, declared row-major as [source, atlas_x, atlas_y] and stamped whole --
## placing a single cell of one of these gives you half a rock.
##   source 1 = Stones Summer (mossy stones, 2x1 pairs; these carry collision,
##              which is why the Scatter layer runs with collision disabled)
##   source 4 = Stones 2 (boulder clusters, 2x2 and 3x2)
##   source 3 = ALL props seasons (row 0 bushes, row 5 tufts -- single tiles)
const ROCK_PAIRS := [
	[[[1, 0, 0], [1, 1, 0]]],
	[[[1, 2, 0], [1, 3, 0]]],
]
const BOULDER_SMALL := [
	[
		[[4, 0, 0], [4, 1, 0]],
		[[4, 0, 1], [4, 1, 1]]],
]
const BOULDER_LARGE := [
	[
		[[4, 0, 2], [4, 1, 2], [4, 2, 2]],
		[[4, 0, 3], [4, 1, 3], [4, 2, 3]]],
]
const BUSH_ROW := 0
const TUFT_ROW := 5
const SRC_FENCE := 0
const FENCE_L := Vector2i(0, 2)
const FENCE_M := Vector2i(1, 2)
const FENCE_R := Vector2i(2, 2)

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

@export_group("Path")
## Centre line of the dirt path, in tile coordinates; interpolated between
## points. The path is two tiles wide where the ledge allows it and is always
## clamped to walkable ground, one row clear of the cliff lip.
@export var path_waypoints: Array[Vector2i] = [
	Vector2i(1, 11), Vector2i(10, 11), Vector2i(18, 10), Vector2i(24, 9),
	Vector2i(26, 8), Vector2i(33, 8), Vector2i(36, 9), Vector2i(44, 11),
	Vector2i(52, 12), Vector2i(60, 11), Vector2i(68, 10), Vector2i(76, 8),
]

@export_group("Features")
## Leftmost column of the 4-wide waterfall. The ledge lip is flattened across
## those columns so the fall lands square on the edge.
@export var waterfall_column: int = 44
@export var build_waterfall: bool = true
## Column the cave arch is carved into, at the base of the mountain wall.
@export var cave_column: int = 76
@export var build_cave: bool = true

@export_group("Dressing")
## Tiles the scatter and fencing must leave alone -- the Forester's camp and
## the props at the collapsed span live here. The props themselves are authored
## in the scene under "Dressing"; the builder only keeps their ground clear.
@export var keep_clear: Array[Vector2i] = [
	Vector2i(52, 10), Vector2i(49, 11), Vector2i(48, 10), Vector2i(54, 11),
	Vector2i(23, 11), Vector2i(24, 12),
	Vector2i(22, 11),  ## Cedric's page at the break
]

@export_group("Props")
@export var place_props: bool = true
@export var pine_scene: PackedScene = preload("res://objects/pine_tree_large.tscn")
## Columns between pines along the base of the mountain wall.
@export var pine_spacing: int = 3
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
	# Flatten the lip under the waterfall so the 4x4 fall lands square.
	if build_waterfall and waterfall_column >= 0 and waterfall_column < level_width:
		var lip := _bot[waterfall_column]
		for x in range(waterfall_column, min(waterfall_column + 4, level_width)):
			_bot[x] = lip


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
	for n in ["Water", "Cliffs", "Ground", "Path", "Waterfall", "Scatter", "Fences"]:
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

	if build_cave:
		_build_cave(cliffs)
	var reserved := _build_path(_layer("Path"))
	if build_waterfall:
		for k in _build_waterfall(_layer("Waterfall")):
			reserved[k] = true
	# keep the entities' own tiles clear
	for rc in [Vector2i(50, 10), Vector2i(cave_column, 8), Vector2i(cave_column, 7)]:
		reserved[rc] = true
	# and a one-tile margin around every dressing prop
	for kc in keep_clear:
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				reserved[kc + Vector2i(ox, oy)] = true
	var used := _build_scatter(_layer("Scatter"), reserved)
	_build_fences(_layer("Fences"), reserved, used)

	_build_collision(parent)
	if place_props:
		_build_props(parent)


## Carves the arch into the base of the mountain wall, overwriting the rock
## face already painted there.
func _build_cave(cliffs: TileMapLayer) -> void:
	if cave_column < 0 or cave_column >= level_width:
		return
	if _top[cave_column] < 2:
		push_warning("level_2_builder: wall at column %d is too short for the cave arch." % cave_column)
		return
	cliffs.set_cell(Vector2i(cave_column, _top[cave_column] - 2), SRC_CLIFF, T_CAVE_TOP)
	cliffs.set_cell(Vector2i(cave_column, _top[cave_column] - 1), SRC_CLIFF, T_CAVE_BOT)


func _build_path(path: TileMapLayer) -> Dictionary:
	var cells := {}
	if path == null or path_waypoints.size() < 2:
		return cells
	# Centre row per column, interpolated along the waypoints.
	var centre := {}
	for i in path_waypoints.size() - 1:
		var a := path_waypoints[i]
		var b := path_waypoints[i + 1]
		for x in range(a.x, min(b.x, level_width)):
			var f := 0.0 if b.x == a.x else float(x - a.x) / float(b.x - a.x)
			centre[x] = int(round(lerp(float(a.y), float(b.y), f)))
	var lastp := path_waypoints[path_waypoints.size() - 1]
	if lastp.x >= 0 and lastp.x < level_width:
		centre[lastp.x] = lastp.y

	# Two rows wide, clamped to walkable ground and kept clear of the lip.
	for x in centre.keys():
		if x < 0 or x >= level_width:
			continue
		var lo: int = _top[x]
		var hi: int = max(_top[x], _bot[x] - 1)
		# Nudge the centre onto the ledge rather than dropping the column, so
		# the path never breaks where the ledge narrows.
		var cy: int = clampi(int(centre[x]), lo, hi)
		cells[Vector2i(x, cy)] = true
		if cy + 1 <= hi:
			cells[Vector2i(x, cy + 1)] = true

	for c in cells.keys():
		var mask := 0
		if cells.has(c + Vector2i(0, -1)): mask |= 1
		if cells.has(c + Vector2i(1, 0)): mask |= 2
		if cells.has(c + Vector2i(0, 1)): mask |= 4
		if cells.has(c + Vector2i(-1, 0)): mask |= 8
		path.set_cell(c, SRC_SOIL, PATH_TILES[mask])
	return cells


## 4x4 stamp straddling the lip: row 0 on the grass, rows 1-2 down the rock
## face, row 3 landing in the sea.
func _build_waterfall(fall: TileMapLayer) -> Dictionary:
	var cells := {}
	if fall == null or waterfall_column < 0 or waterfall_column >= level_width:
		return cells
	var y0 := _bot[waterfall_column]
	for dx in 4:
		for dy in 4:
			var x := waterfall_column + dx
			var y := y0 + dy
			if x < level_width and y < level_height:
				fall.set_cell(Vector2i(x, y), SRC_FALL, Vector2i(dx, dy))
				cells[Vector2i(x, y)] = true
	return cells


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
		var jitter := int(_rnd(x, 5) * 9) - 4
		i = _add_pine(props, owner_node, i,
			Vector2(x * 16 + 8 + jitter, _top[x] * 16 + 12 + int(_rnd(x, 11) * 6)))
	# a few standing out on the ledge itself
	for x in range(6, level_width - 6, 11):
		if x >= pine_skip_from and x <= pine_skip_to:
			continue
		if x >= waterfall_column - 1 and x <= waterfall_column + 4:
			continue
		var y := _bot[x] - 2
		if y - _top[x] < 3:
			continue
		i = _add_pine(props, owner_node, i, Vector2(x * 16 + 10, y * 16 + 8))


func _add_pine(props: Node2D, owner_node: Node, i: int, pos: Vector2) -> int:
	var pine := pine_scene.instantiate() as Node2D
	pine.name = "Pine%d" % i
	pine.position = pos
	pine.z_index = 5
	props.add_child(pine)
	if owner_node:
		pine.owner = owner_node
	return i + 1


## Deterministic 0..1, matching the bake script so both produce the same scatter.
func _rnd(a: int, b: int) -> float:
	var t := (a * 374761393 + b * 668265263) & 0xFFFFFFFF
	t = (t ^ (t >> 13)) & 0xFFFFFFFF
	t = (t * 1274126177) & 0xFFFFFFFF
	return float((t ^ (t >> 16)) & 0xFFFFFFFF) / 4294967296.0


## Rocks, boulders and greenery. Runs with collision disabled on the layer --
## the Stones Summer tiles carry collision polygons, and 150-odd solid cells on
## a ledge this narrow would need playtesting before anyone turns them on.
func _build_scatter(scatter: TileMapLayer, reserved: Dictionary) -> Dictionary:
	var used := {}
	if scatter == null:
		return used
	_scatter_group(scatter, reserved, used, BOULDER_LARGE, 40, 101, 1)
	_scatter_group(scatter, reserved, used, BOULDER_SMALL, 90, 211, 1)
	_scatter_group(scatter, reserved, used, ROCK_PAIRS, 420, 307, 0)
	for x in level_width:
		for y in range(_top[x], _bot[x] + 1):
			var c := Vector2i(x, y)
			if reserved.has(c) or used.has(c):
				continue
			var n := _rnd(x, y + 613)
			var edge: bool = (y == _bot[x] or y == _top[x])
			if not edge and n > 0.80:
				scatter.set_cell(c, 3, Vector2i(int(_rnd(x, y + 57) * 8) % 8, BUSH_ROW))
				used[c] = true
			elif n > 0.62:
				scatter.set_cell(c, 3, Vector2i(int(_rnd(x, y + 23) * 6) % 6, TUFT_ROW))
				used[c] = true
	return used


func _scatter_group(scatter: TileMapLayer, reserved: Dictionary, used: Dictionary,
		stamps: Array, tries: int, salt: int, margin: int) -> void:
	for i in tries:
		var x := int(_rnd(i, salt) * level_width)
		if x < 0 or x >= level_width:
			continue
		if _bot[x] - _top[x] < 2 + margin:
			continue
		var span: int = max(1, _bot[x] - _top[x] - 2 * margin)
		var y := _top[x] + margin + int(_rnd(i, salt + 1) * span)
		var stamp: Array = stamps[int(_rnd(i, salt + 2) * stamps.size()) % stamps.size()]
		if not _stamp_fits(x, y, stamp, reserved, used):
			continue
		for dy in stamp.size():
			var row: Array = stamp[dy]
			for dx in row.size():
				var t: Array = row[dx]
				var c := Vector2i(x + dx, y + dy)
				scatter.set_cell(c, int(t[0]), Vector2i(int(t[1]), int(t[2])))
				used[c] = true


func _stamp_fits(x: int, y: int, stamp: Array, reserved: Dictionary, used: Dictionary) -> bool:
	for dy in stamp.size():
		var row: Array = stamp[dy]
		for dx in row.size():
			var cx := x + dx
			var cy := y + dy
			if cx < 0 or cx >= level_width:
				return false
			if cy < _top[cx] or cy > _bot[cx]:
				return false
			var c := Vector2i(cx, cy)
			if reserved.has(c) or used.has(c):
				return false
	return true


## A railing on the lip row, stepping with it. Segments break wherever the lip
## drops more than a row so the posts still read as joined, with gaps left so it
## looks maintained in places rather than walled off.
func _build_fences(fences: TileMapLayer, reserved: Dictionary, used: Dictionary) -> void:
	if fences == null:
		return
	var segments: Array = []
	var cur: Array = []
	for c in level_width:
		if _fence_ok(c, reserved) and (cur.is_empty() or absi(_bot[c] - _bot[cur[cur.size() - 1]]) <= 1):
			cur.append(c)
		else:
			if cur.size() >= 4:
				segments.append(cur)
			cur = [c] if _fence_ok(c, reserved) else []
	if cur.size() >= 4:
		segments.append(cur)

	var sc := _layer("Scatter")
	for seg in segments:
		var i := 0
		while i < seg.size():
			var span := 5 + int(_rnd(seg[i], 7) * 7)
			var run: Array = seg.slice(i, min(i + span, seg.size()))
			if run.size() >= 3:
				for j in run.size():
					var c: int = run[j]
					var t := FENCE_L if j == 0 else (FENCE_R if j == run.size() - 1 else FENCE_M)
					fences.set_cell(Vector2i(c, _bot[c]), SRC_FENCE, t)
					# a fence wins the cell over whatever scatter landed there
					if sc and used.has(Vector2i(c, _bot[c])):
						sc.erase_cell(Vector2i(c, _bot[c]))
			i += span + 3 + int(_rnd(seg[i], 13) * 5)


func _fence_ok(c: int, reserved: Dictionary) -> bool:
	if c < 1 or c >= level_width - 1:
		return false
	if _bot[c] - _top[c] < 3:
		return false
	if reserved.has(Vector2i(c, _bot[c])):
		return false
	return true
