extends Node

@export var UI_can_analyze: Control

@onready var timer = $Timer

var parent = null

var analysis = []

var was_E_pressed = false

# Called when the node enters the scene tree for the first time.
func _ready():
	UI_can_analyze.visible = false
	parent = get_parent()
	timer.timeout.connect(on_analysis_ended)

func _physics_process(_delta):
	if Input.is_physical_key_pressed(KEY_E) and not was_E_pressed:
		if not analysis.is_empty():
			var obj = analysis[0]
			
			obj.queue_free()
			if parent != null:
				parent.is_stopped = true
				timer.start()
	
	was_E_pressed = Input.is_physical_key_pressed(KEY_E)

func on_analysis_ended():
	parent.is_stopped = false

func _on_body_entered(body):
	if body.is_in_group("Analyzis"):
		analysis.push_back(body)
		
		UI_can_analyze.visible = true


func _on_body_exited(body):
	if body.is_in_group("Analyzis"):
		
		analysis.remove_at( analysis.find(body) )
		
		if analysis.is_empty():
			UI_can_analyze.visible = false
