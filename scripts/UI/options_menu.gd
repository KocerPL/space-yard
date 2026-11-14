extends Control
signal returnButtonPressed
@export_category("custom")
@export var volumeSlider:HSlider

func _ready() -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	volumeSlider.value = Config.master_volume*100;
func _on_return_button_pressed() -> void:
	returnButtonPressed.emit();
	hide();
	

func _on_volume_slider_value_changed(value: float) -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	var linear_value = clamp(value, 0.0, 100.0) / 100.0
	Config.master_volume = linear_value;
	Config.save_volume()
