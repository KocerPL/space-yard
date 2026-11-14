extends Control
signal returnButtonPressed
@export_category("custom")
@export var volumeSlider: HSlider

# Bare Config fails when the class cache predates the autoload.
@onready var _config: Node = get_node("/root/Config")


func _ready() -> void:
	volumeSlider.value = _config.master_volume * 100.0


func _on_return_button_pressed() -> void:
	returnButtonPressed.emit()
	hide()


func _on_volume_slider_value_changed(value: float) -> void:
	var linear_value := clampf(value, 0.0, 100.0) / 100.0
	_config.master_volume = linear_value
	_config.save_volume()
