extends CanvasLayer
@export_category("custom")
@export var gameMenu:Control;


func _unhandled_input(event: InputEvent) -> void:
	# 2. Check if the Escape key ("ui_cancel") was just pressed
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = true;
		gameMenu.show();


func _on_game_menu_resume_pressed() -> void:
	get_tree().paused = false;
