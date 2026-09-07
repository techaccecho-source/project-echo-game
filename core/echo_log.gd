extends Node
## Autoload "EchoLog" — the ARG collectible record.
##
## Holds which of Cedric's blog fragments the player has recovered, persists
## that to user:// so it survives quitting, and owns the journal UI. Levels only
## ever talk to this: `EchoLog.collect(fragment)` and `EchoLog.open_journal()`.

signal collected(fragment: Fragment)
signal changed

const SAVE_PATH := "user://echo_log.cfg"

## Every fragment in the game, in reading order. Paths that do not exist yet are
## skipped silently, so Levels 1/3/4 can add theirs without touching anything
## else — drop the .tres in res://fragments/ and list it here.
const MANIFEST := [
	"res://fragments/fragment_01_hollow_stump.tres",
	"res://fragments/fragment_02_the_ledge_gives.tres",
]

## The fragments that actually exist, in MANIFEST order.
var fragments: Array[Fragment] = []

var _found: Dictionary = {}
var _journal: JournalUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest()
	_load_save()
	_journal = JournalUI.new()
	add_child(_journal)


func _load_manifest() -> void:
	fragments.clear()
	for path in MANIFEST:
		if not ResourceLoader.exists(path):
			continue
		var f := load(path) as Fragment
		if f == null or f.id == "":
			push_warning("EchoLog: %s is not a valid Fragment." % path)
			continue
		fragments.append(f)


# --- state ------------------------------------------------------------------

func has_fragment(id: String) -> bool:
	return _found.has(id)


func found_count() -> int:
	return _found.size()


func total_count() -> int:
	return fragments.size()


## Record a fragment. Returns false if it was already held, so pickups can tell
## a real find from a re-entry into the level.
func collect(fragment: Fragment) -> bool:
	if fragment == null or fragment.id == "":
		push_warning("EchoLog.collect() called with an empty fragment.")
		return false
	if _found.has(fragment.id):
		return false
	_found[fragment.id] = true
	_save()
	changed.emit()
	collected.emit(fragment)
	return true


func open_journal(focus_id: String = "") -> void:
	if _journal:
		_journal.open(focus_id)


func close_journal() -> void:
	if _journal:
		_journal.close()


func journal_is_open() -> bool:
	return _journal != null and _journal.is_open


## Wipe progress. Handy while building levels; not wired to any UI.
func reset() -> void:
	_found.clear()
	_save()
	changed.emit()


# --- persistence ------------------------------------------------------------

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if not cfg.has_section("fragments"):
		return
	for id in cfg.get_section_keys("fragments"):
		if cfg.get_value("fragments", id, false):
			_found[id] = true


func _save() -> void:
	var cfg := ConfigFile.new()
	for id in _found:
		cfg.set_value("fragments", id, true)
	cfg.save(SAVE_PATH)
