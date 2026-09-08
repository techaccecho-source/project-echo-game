extends Area2D

class_name InteractionArea

# Text that will be shown above an object to show it can be interacted with
@export var action_name: String = "interact"

# Input action (from the project input map) that triggers this interaction.
# Defaults to "interact" (E) so every existing interactable is unchanged; the
# mahogany tree sets this to "interact_alt" (B / left click).
@export var input_action: StringName = "interact"

# Key/button hint shown inside the prompt label, e.g. "E" or "B / Click".
@export var key_prompt: String = "E"

var interact: Callable = func():
	pass

func _on_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player")):
		InteractionManager.register_area(self)


func _on_body_exited(body: Node2D) -> void:
	if (body.is_in_group("player")):
		InteractionManager.deregister_area(self)
