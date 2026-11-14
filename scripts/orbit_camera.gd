extends Node3D
## Pivot that follows `target`; dragging with the left mouse button orbits it.
## Expects a SpringArm3D child holding the Camera3D, so the camera stops at terrain instead of clipping.

@export var target: Node3D
@export var height := 1.0
@export var sensitivity := 0.005
@export var pitch_limits := Vector2(-80.0, 10.0) # degrees
## On start the camera zooms in from this far out to the spring arm's length, over intro_time seconds.
@export var intro_distance := 30.0
@export var intro_time := 3.0

@onready var _arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	if target is CollisionObject3D:
		_arm.add_excluded_object(target.get_rid())
	var length := _arm.spring_length
	_arm.spring_length = intro_distance
	create_tween().tween_property(_arm, "spring_length", length, intro_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# captured while held, so the drag doesn't stop at the window edge
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rotation.y -= event.relative.x * sensitivity
		rotation.x = clampf(rotation.x - event.relative.y * sensitivity, deg_to_rad(pitch_limits.x), deg_to_rad(pitch_limits.y))


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.get_global_transform_interpolated().origin + Vector3.UP * height
