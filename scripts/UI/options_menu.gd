extends Control
signal returnButtonPressed

func _on_return_button_pressed() -> void:
	returnButtonPressed.emit();
	hide();


func _on_volume_slider_value_changed(value: float) -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	var linear_value = clamp(value, 0.0, 100.0) / 100.0
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(linear_value))
