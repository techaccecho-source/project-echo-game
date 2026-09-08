extends Panel

## Emitted when the player clicks a recovered page. The inventory UI listens,
## rather than this slot reaching up through the tree to find it.
signal read_requested(fragment: Fragment)

@onready var item_visual: Sprite2D = $CenterContainer/Panel/item_display
@onready var amount_text: Label = $CenterContainer/Panel/Label

var current_slot: InvSlot

func _ready():
	# Children default to MOUSE_FILTER_STOP and would swallow the click before
	# this Panel ever sees it, so let everything through to the slot itself.
	for child in find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update(slot: InvSlot):
	current_slot = slot
	if !slot.item:
		item_visual.visible = false
		amount_text.visible = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = ""
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		if slot.amount > 1:
			amount_text.visible = true
		amount_text.text = str(slot.amount)
		# Pages are readable; everything else is just carried.
		if slot.item is Fragment:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			tooltip_text = "Read \"%s\"" % (slot.item as Fragment).title
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			tooltip_text = slot.item.name

func _gui_input(event: InputEvent) -> void:
	if current_slot == null or not (current_slot.item is Fragment):
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		read_requested.emit(current_slot.item as Fragment)
