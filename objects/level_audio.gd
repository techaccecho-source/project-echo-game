extends Node
class_name LevelAudio
## Drop this into a level to say what it should sound like.
##
## Deliberately declarative: the level owns no players and no fade logic, it
## just names a track and some looping layers and hands them to the Audio
## autoload. That is what makes it reusable — Level 1 wants the same node with
## different paths.
##
## Layers are named, so a level can fade one out mid-play (`Audio.stop_ambience`)
## without disturbing the rest.

## Looping bed for this level. Leave empty to keep whatever is already playing.
@export_file("*.ogg", "*.wav", "*.mp3") var music: String = ""
@export var music_volume_db: float = 0.0
@export var music_fade: float = 2.0

## Named looping layers, e.g. {"wind": "res://audio/ambience/wind_loop.wav"}.
@export var ambience: Dictionary = {}
## Per-layer volume in dB, same keys as `ambience`. Missing keys default to 0.
@export var ambience_volume_db: Dictionary = {}
@export var ambience_fade: float = 2.5

## Clear layers this level did not ask for. Off by default so a level can add a
## layer to whatever the previous one had.
@export var exclusive_ambience: bool = true


func _ready() -> void:
	if exclusive_ambience:
		Audio.stop_all_ambience(ambience_fade)
	if music != "":
		Audio.play_music(music, music_fade, music_volume_db)
	for name in ambience:
		var vol: float = ambience_volume_db.get(name, 0.0)
		Audio.ambience(str(name), str(ambience[name]), vol, ambience_fade)
