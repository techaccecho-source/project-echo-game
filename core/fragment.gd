extends Resource
class_name Fragment
## One recovered page of Cedric Spooks Queen's blog.
##
## Fragments are the game's collectible spine — one in Level 1, one in Level 2,
## three in Level 3, one in Level 4. They are plain resources so writing a new
## one is a content job, not a code job: duplicate a .tres, change the text,
## add its path to EchoLog.MANIFEST, and point a fragment_pickup at it.

## Stable key. Never reuse or renumber one — saves are keyed on it.
@export var id: String = ""
## Shown in the journal's index list.
@export var title: String = ""
## Small line above the title, e.g. "ENTRY 14".
@export var entry_label: String = ""
## Which case/level this belongs to. 0 = unassigned.
@export var level: int = 0
## Where the player picked it up, e.g. "the washed-out ledge".
@export var found_at: String = ""
## The page itself. BBCode is allowed — the journal renders it rich.
@export_multiline var body: String = ""
## Damage/censor note printed under the body in a quieter colour.
@export_multiline var footer: String = ""
