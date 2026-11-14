extends Control
signal resumePressed
@export_group("custom")
@export var optionsMenu:Control
@export var mainControls:Control
func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false;
	get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")
	

func _on_options_button_pressed() -> void:
	mainControls.hide();
	optionsMenu.show();
	
	


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_resume_button_pressed() -> void:
	resumePressed.emit()
	hide()
	


func _on_options_menu_return_button_pressed() -> void:
	mainControls.show();
	
