extends Resource

class_name Inv

signal update
@export var slots: Array[InvSlot]

# True if the player is carrying at least one of this item. Used to gate things
# like the rubble wall on the axe.
func has(item: InvItem) -> bool:
	if item == null:
		return false
	for slot in slots:
		if slot != null and slot.item == item and slot.amount > 0:
			return true
	return false

func insert(item: InvItem):
	# If the first slot is open, then its going to add a new item to that slot.
	# If the item passed equals item in a slot, add to amount
	var item_slots = slots.filter(func(slot): return slot.item == item)
	if !item_slots.is_empty():
		item_slots[0].amount += 1
	# If slot is empty
	else:
		var empty_slots = slots.filter(func(slot): return slot.item == null)
		if !empty_slots.is_empty():
			empty_slots[0].item = item
			empty_slots[0].amount = 1
	update.emit()
