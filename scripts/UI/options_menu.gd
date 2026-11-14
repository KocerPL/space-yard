extends Control
signal returnButtonPressed

func _on_return_button_pressed() -> void:
	returnButtonPressed.emit();
	hide();
