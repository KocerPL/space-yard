extends Control

@export var fade_in_time := 2.0

@onready var _fade: ColorRect = $FadeIn


func _ready() -> void:
	if _fade == null:
		return
	_fade.modulate.a = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, fade_in_time)
	tw.finished.connect(func() -> void:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
	if !MusicPlayer.is_playing():
		MusicPlayer.start();


func _on_team_memers_button_pressed() -> void:
	get_tree().change_scene_to_file("res://assets/img/icons/Authors.tscn")


func _on_github_button_pressed() -> void:
	OS.shell_open("https://github.com/KocerPL/space-yard")


func _on_nasa_space_apps_button_pressed() -> void:
	OS.shell_open("https://www.spaceappschallenge.org/")


func _on_play_button_pressed() -> void:
	Loading.load_scene("res://scenes/terrain_sandbox.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit();


func _on_options_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/options_independent.tscn")
