extends Control

func _on_team_memers_button_pressed() -> void:
	get_tree().change_scene_to_file("res://assets/img/icons/Authors.tscn")


func _on_github_button_pressed() -> void:
	OS.shell_open("https://github.com/KocerPL/space-yard")


func _on_nasa_space_apps_button_pressed() -> void:
	OS.shell_open("https://www.spaceappschallenge.org/")


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/terrain_sandbox.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit();


func _on_options_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/options_independent.tscn")
