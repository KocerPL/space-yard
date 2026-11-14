extends Node3D
## Pivot that follows `target`; mouse orbits it. Click to capture the mouse, Esc to release.
## Expects a SpringArm3D child holding the Camera3D, so the camera stops at terrain instead of clipping.

@export var target: Node3D
@export var height := 1.0
@export var sensitivity := 0.005
@export var pitch_limits := Vector2(-80.0, 10.0) # degrees

@onready var _arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	if target is CollisionObject3D:
		_arm.add_excluded_object(target.get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensitivity
		rotation.x = clampf(rotation.x - event.relative.y * sensitivity, deg_to_rad(pitch_limits.x), deg_to_rad(pitch_limits.y))


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.get_global_transform_interpolated().origin + Vector3.UP * height
