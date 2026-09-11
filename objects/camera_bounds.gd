extends Node
class_name CameraBounds
## Stops the camera showing past the edge of a level.
##
## Camera2D limits live on the camera, but the camera belongs to the persistent
## shell rather than to any level — so each level declares its own bounds here,
## and they are applied on load and **put back on unload**. Without the restore,
## Level 2's limits would still be clamping Level 1's camera after you leave.
##
## The camera is driven by a RemoteTransform2D on the player, which overwrites
## its position every frame. That is fine: Camera2D applies its limits when it
## works out what to draw, not by moving itself, so an externally positioned
## camera still respects them.

## Godot's own "no limit" sentinel.
const NO_LIMIT := 10000000

## Area the camera may show, in level coordinates.
@export var bounds: Rect2i = Rect2i(0, 0, 1280, 416)
@export_group("Which edges")
@export var clamp_left: bool = true
@export var clamp_top: bool = true
@export var clamp_right: bool = true
@export var clamp_bottom: bool = true
@export_group("Feel")
## Ease into the clamp instead of stopping dead. Off by default so this does
## not quietly change how the camera feels everywhere else.
@export var smoothed: bool = false
@export var smoothing_speed: float = 8.0

## Which instance currently owns the camera, and the limits as they were
## before ANY of us touched it.
##
## Static because a respawn overlaps two levels: SceneManager adds the new one
## and only queue_frees the old, so the new instance applies its limits and
## then the old one's _exit_tree fires and hands the camera back to defaults —
## wiping the limits that had just been set. Ownership makes the departing
## instance keep its hands off if someone else has taken over.
static var _owner: CameraBounds = null
static var _pristine: Dictionary = {}
static var _pristine_cam: Camera2D = null

var _cam: Camera2D


func _ready() -> void:
	_apply()


func _apply() -> void:
	_cam = get_viewport().get_camera_2d()
	if _cam == null:
		# On a fresh scene load the camera may not be current yet.
		await get_tree().process_frame
		_cam = get_viewport().get_camera_2d()
	if _cam == null:
		push_warning("CameraBounds: no active Camera2D to clamp.")
		return

	# Only the first instance to touch a given camera records its untouched
	# state; later ones would just record the previous level's clamp.
	if _owner == null or _pristine_cam != _cam:
		_pristine = {
			"l": _cam.limit_left, "t": _cam.limit_top,
			"r": _cam.limit_right, "b": _cam.limit_bottom,
			"sm": _cam.position_smoothing_enabled,
			"sp": _cam.position_smoothing_speed,
		}
		_pristine_cam = _cam
	_owner = self
	_cam.limit_left = bounds.position.x if clamp_left else -NO_LIMIT
	_cam.limit_top = bounds.position.y if clamp_top else -NO_LIMIT
	_cam.limit_right = bounds.end.x if clamp_right else NO_LIMIT
	_cam.limit_bottom = bounds.end.y if clamp_bottom else NO_LIMIT
	if smoothed:
		_cam.position_smoothing_enabled = true
		_cam.position_smoothing_speed = smoothing_speed


func _exit_tree() -> void:
	# Someone else has taken the camera since (a respawn, or the next level
	# loading before this one is freed) — leave their limits alone.
	if _owner != self:
		return
	_owner = null
	# The shell's camera outlives this level, so hand it back as we found it.
	# On a full scene change the camera is being freed too, hence the guard.
	if _cam == null or not is_instance_valid(_cam) or _pristine.is_empty():
		return
	if _pristine_cam != _cam:
		return
	_cam.limit_left = _pristine["l"]
	_cam.limit_top = _pristine["t"]
	_cam.limit_right = _pristine["r"]
	_cam.limit_bottom = _pristine["b"]
	_cam.position_smoothing_enabled = _pristine["sm"]
	_cam.position_smoothing_speed = _pristine["sp"]
	_pristine_cam = null
	_pristine = {}
