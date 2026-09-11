extends Node
## Autoload "Audio" — every sound in the game goes through here.
##
## Shared across all levels on purpose: a level should say what it wants to
## hear, not own players, buses or fade logic. Levels talk to it through
## `objects/level_audio.tscn`; scripts fire one-shots with `sfx()`.
##
## Three buses, defined in default_bus_layout.tres: Music, Ambience, SFX.

const MUSIC_BUS := "Music"
const AMBIENCE_BUS := "Ambience"
const SFX_BUS := "SFX"

## How many one-shots can overlap before the oldest is reused.
const SFX_VOICES := 12

## One player per track, freed once it has faded out. Ping-ponging between two
## fixed players looks tidier but is a trap: a fade-out tween left over from the
## previous change will stop a player that a newer call has already restarted,
## and the music dies silently. One player per track cannot race with itself.
var _music: AudioStreamPlayer
var _music_path: String = ""
var _ambience: Dictionary = {}        ## name -> AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		_sfx.append(_make_player(SFX_BUS))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## Imported WAVs default to no looping unless the file carries a loop marker.
## Beds and ambience must loop, so make sure of it here rather than relying on
## every future audio file being authored correctly.
func _as_loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = 0
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


func _load(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


# --- music ------------------------------------------------------------------

## Crossfade to a track. Calling it again with the same path does nothing, so
## levels can ask for their music on every load without restarting it.
func play_music(path: String, fade: float = 1.5, volume_db: float = 0.0) -> void:
	if path == _music_path:
		return
	var stream := _load(path)
	if stream == null:
		if path != "":
			push_warning("Audio: no music at %s" % path)
		return
	_music_path = path
	var old := _music

	_music = _make_player(MUSIC_BUS)
	_music.stream = _as_loop(stream)
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", volume_db, fade)

	if old != null and is_instance_valid(old):
		var t := create_tween()
		t.tween_property(old, "volume_db", -40.0, fade)
		t.tween_callback(old.queue_free)


func stop_music(fade: float = 1.2) -> void:
	_music_path = ""
	if _music == null or not is_instance_valid(_music):
		return
	var old := _music
	_music = null
	var t := create_tween()
	t.tween_property(old, "volume_db", -40.0, fade)
	t.tween_callback(old.queue_free)


## True while a track is actually audible. Useful when debugging a level that
## seems to have gone quiet.
func music_playing() -> bool:
	return _music != null and is_instance_valid(_music) and _music.playing


# --- ambience ---------------------------------------------------------------

## Start (or keep) a named looping layer — "wind", "sea", and so on. Layers are
## independent so a level can fade one out without touching the others.
func ambience(name: String, path: String, volume_db: float = 0.0,
		fade: float = 1.5) -> void:
	if _ambience.has(name):
		return
	var stream := _load(path)
	if stream == null:
		push_warning("Audio: no ambience at %s" % path)
		return
	var p := _make_player(AMBIENCE_BUS)
	p.stream = _as_loop(stream)
	p.volume_db = -40.0
	p.play()
	# Layers that start together shouldn't loop in lockstep.
	p.seek(randf() * 2.0)
	_ambience[name] = p
	create_tween().tween_property(p, "volume_db", volume_db, fade)


func stop_ambience(name: String, fade: float = 1.2) -> void:
	if not _ambience.has(name):
		return
	var p: AudioStreamPlayer = _ambience[name]
	_ambience.erase(name)
	var t := create_tween()
	t.tween_property(p, "volume_db", -40.0, fade)
	t.tween_callback(p.queue_free)


func stop_all_ambience(fade: float = 1.2) -> void:
	for name in _ambience.keys():
		stop_ambience(name, fade)


# --- one-shots --------------------------------------------------------------

## Fire and forget. `pitch_spread` randomises pitch a little, which is what
## stops repeated footsteps sounding like a machine.
func sfx(path: String, volume_db: float = 0.0, pitch_spread: float = 0.0) -> void:
	var stream := _load(path)
	if stream == null:
		return
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.play()


## Same, but positioned in the world so it pans and falls off with distance.
func sfx_at(path: String, world_pos: Vector2, volume_db: float = 0.0,
		pitch_spread: float = 0.0) -> void:
	var stream := _load(path)
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.bus = SFX_BUS
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.max_distance = 600.0
	p.global_position = world_pos
	get_tree().current_scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- mixing -----------------------------------------------------------------

func set_bus_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0, 1.0)))


func get_bus_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(i)) if i >= 0 else 0.0
