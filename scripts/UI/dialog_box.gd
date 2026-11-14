extends Node

@export_file_path("*.json") var text_file: String

var scene_text = {}
var selected_text = []
var in_progress = false

@onready var background = $Panel
@onready var text_label: RichTextLabel = $Panel/RichTextLabel

@onready var text_timer: Timer = $Timer

func _ready():
	background.visible = false
	load_scene_text()
	text_timer.timeout.connect(on_timeout)


func start_dialog(dialog_key: String):
	if in_progress:
		return false
	
	if scene_text == null:
		print("scene text was not loaded")
		return false
	
	if not scene_text.has(dialog_key):
		print("Invalid key: ", dialog_key)
		return false
	
	in_progress = true
	selected_text = scene_text[dialog_key].duplicate()
	
	background.visible = true
	show_text()
	
	return true


func load_scene_text():
	var file = FileAccess.open(text_file, FileAccess.READ)
	var json_text = file.get_as_text()
	scene_text = JSON.parse_string(json_text)
	
	print(scene_text)

func show_text():
	text_label.text = selected_text.pop_front()
	text_label.visible_characters = 0
	text_timer.start()


func next_line():
	if not in_progress:
		return
	
	if selected_text.size() > 0:
		show_text()
	else:
		end_dialog()


func end_dialog():
	text_label.text = ""
	background.visible = false
	in_progress = false


func on_timeout():
	text_label.visible_characters += 1
	
	if text_label.visible_characters >= text_label.text.length():
		text_timer.stop()
