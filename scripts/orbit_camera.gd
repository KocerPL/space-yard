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
## The mouse wheel zooms between these distances (m).
@export var zoom_limits := Vector2(3.0, 20.0)
## Fraction of the distance one wheel notch zooms by, so zooming is finer up close.
@export var zoom_step := 0.12
## How fast the camera eases to the zoomed distance.
@export var zoom_smoothing := 10.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _zoom := _arm.spring_length # distance the camera eases to
var _intro: Tween


func _ready() -> void:
	if target is CollisionObject3D:
		_arm.add_excluded_object(target.get_rid())
	_arm.spring_length = intro_distance
	_intro = create_tween()
	_intro.tween_property(_arm, "spring_length", _zoom, intro_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# captured while held, so the drag doesn't stop at the window edge
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rotation.y -= event.relative.x * sensitivity
		rotation.x = clampf(rotation.x - event.relative.y * sensitivity, deg_to_rad(pitch_limits.x), deg_to_rad(pitch_limits.y))
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _intro and _intro.is_running():
			_intro.kill() # the player takes over; ease on from wherever the intro got to
			_zoom = _arm.spring_length
		var dir := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		_zoom = clampf(_zoom * (1.0 + dir * zoom_step), zoom_limits.x, zoom_limits.y)


func _process(delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.get_global_transform_interpolated().origin + Vector3.UP * height
	if not (_intro and _intro.is_running()):
		_arm.spring_length = lerpf(_arm.spring_length, _zoom, minf(1.0, zoom_smoothing * delta))
