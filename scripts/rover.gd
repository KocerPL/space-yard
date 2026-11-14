class_name Rover
extends CharacterBody3D
## Arcade rover: W/S drive along -Z, A/D turn in place. The model tilts to the ground; the collider stays upright.

@export var speed := 4.0
@export var acceleration := 6.0
@export var turn_speed := 1.5 # rad/s
@export var turn_acceleration := 4.0 # rad/s²
@export var tilt_smoothing := 6.0
## How fast the model follows the body's height. Lower is softer, so it absorbs drops off rocks.
@export var suspension_smoothing := 12.0
## Half the track (x, sideways) and wheelbase (y, forward), where ground height is sampled for the tilt.
@export var footprint := Vector2(0.6, 0.8)

@export_group("Wheels")
@export var wheel_radius := 0.13
## Corner wheel steering speed, rad/s.
@export var steer_speed := 2.5
## How far above or below its rest height a wheel looks for ground. The body sinks or rises onto its wheels within
## this, which also settles the model down when the upright box collider rests on its edge on a slope.
@export var ground_reach := 0.6
## How fast the wheels follow the ground under them.
@export var wheel_smoothing := 15.0

## Per side, the front wheel hangs off the rocker and the middle and rear wheels off the bogie. Left is the model's +X.
const WHEELS: Array[String] = ["FL", "ML", "RL", "FR", "MR", "RR"]

var _turn := 0.0
var _model_height := 0.0 # model's smoothed world height
var _wheels: Array[Node3D] = []
var _steers: Array[Node3D] = [] # null for the middle wheels, which don't steer
var _rest := PackedVector3Array() # wheel centres in model space
var _pivot_z := PackedFloat32Array() # model-space z of rocker L, R, then bogie L, R
var _ground := PackedFloat32Array([0, 0, 0, 0, 0, 0]) # ground under each wheel, relative to its rest height
var _spin := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _steer := PackedFloat32Array([0, 0, 0, 0, 0, 0])

@onready var _model: Node3D = $Model
@onready var _body: Node3D = $Model/Body
@onready var _rockers: Array[Node3D] = [$Model/Body/Rocker_L, $Model/Body/Rocker_R]
@onready var _bogies: Array[Node3D] = [$Model/Body/Rocker_L/Bogie_L, $Model/Body/Rocker_R/Bogie_R]


func _ready() -> void:
	for n in WHEELS:
		_wheels.append(_model.find_child("Wheel_" + n))
		_steers.append(_model.find_child("Steer_" + n))
		_rest.append(_model.to_local(_wheels[-1].global_position))
	for pivot in _rockers + _bogies:
		_pivot_z.append(_model.to_local(pivot.global_position).z)

	var t := TerrainGenerator.instance
	if t:
		t.register_tracker(self)
		t.ensure_loaded_around(global_position, 1)
		global_position.y = t.sample_height(global_position.x, global_position.z) + 0.5
		reset_physics_interpolation() # teleported, don't interpolate from the old spot
	_model_height = global_position.y


func _exit_tree() -> void:
	if TerrainGenerator.instance:
		TerrainGenerator.instance.unregister_tracker(self)


func _physics_process(delta: float) -> void:
	# shortcut: raw physical keys, move to InputMap actions when rebinding or gamepad support is needed
	var drive := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var steer := float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))

	_turn = move_toward(_turn, steer * turn_speed, turn_acceleration * delta)
	rotate_y(_turn * delta)
	var target := -global_basis.z * drive * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	velocity += get_gravity() * delta
	move_and_slide()

	var up := global_basis.inverse() * _ground_normal()
	var tilted := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, PI) # PI: the model faces +Z
	_model.basis = _model.basis.slerp(tilted, minf(1.0, tilt_smoothing * delta))
	_model_height = lerpf(_model_height, global_position.y, minf(1.0, suspension_smoothing * delta))
	_model.position.y = _model_height - global_position.y

	_sense_ground(delta)
	_pose_suspension()
	_roll_wheels(delta)


## Raycasts under each wheel, rocks included, for how far the ground sits above or below the wheel's rest height.
func _sense_ground(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var up := _model.global_basis.y
	for i in _wheels.size():
		var bottom := _model.to_global(_rest[i] - Vector3(0, wheel_radius, 0))
		var ray := PhysicsRayQueryParameters3D.create(bottom + up * ground_reach, bottom - up * ground_reach, collision_mask, [get_rid()])
		var hit := space.intersect_ray(ray)
		if hit: # airborne wheels hold their pose
			_ground[i] = lerpf(_ground[i], (hit.position - bottom).dot(up), minf(1.0, wheel_smoothing * delta))


## Rocker-bogie: each bogie tilts to fit its middle and rear wheels, each rocker to fit its front wheel and bogie pivot,
## and the body lifts and rolls so that both rockers' pivots sit where that leaves them.
func _pose_suspension() -> void:
	var lift := PackedFloat32Array([0, 0])
	for s in 2:
		var f := s * 3 # front, then middle and rear
		var zf := _rest[f].z
		var zm := _rest[f + 1].z
		var zr := _rest[f + 2].z
		var zp := _pivot_z[s]
		var zb := _pivot_z[2 + s]
		# turning a part by a about X raises a point dz ahead of its pivot by -dz * sin(a)
		var sin_b := clampf((_ground[f + 2] - _ground[f + 1]) / (zm - zr), -0.7, 0.7)
		var hb := _ground[f + 1] + (zm - zb) * sin_b
		var sin_r := clampf((hb - _ground[f]) / (zf - zb), -0.7, 0.7)
		lift[s] = _ground[f] + (zf - zp) * sin_r
		_rockers[s].basis = Basis(Vector3.RIGHT, asin(sin_r))
		_bogies[s].basis = Basis(Vector3.RIGHT, asin(sin_b) - asin(sin_r))
	var track := _rest[0].x - _rest[3].x # body roll moves the wheels by their own x, not the pivots'
	var roll := asin(clampf((lift[0] - lift[1]) / track, -0.5, 0.5))
	_body.transform = Transform3D(Basis(Vector3.BACK, roll), Vector3.UP * (lift[0] + lift[1]) / 2)


## Spins each wheel by the ground speed under it and steers the corner wheels along it, so turning in place
## swings them tangent to the turn like on the real rover.
func _roll_wheels(delta: float) -> void:
	var to_model := _model.global_basis.inverse()
	for i in _wheels.size():
		var v := to_model * (velocity + Vector3(0, _turn, 0).cross(_wheels[i].global_position - global_position))
		if _steers[i] and Vector2(v.x, v.z).length() > 0.05:
			var target := atan2(v.x, v.z)
			if absf(target) > PI / 2: # roll backwards rather than steer past 90°
				target = wrapf(target + PI, -PI, PI)
			_steer[i] = move_toward(_steer[i], target, steer_speed * delta)
			_steers[i].basis = Basis(Vector3.UP, _steer[i])
		_spin[i] = wrapf(_spin[i] + (v.x * sin(_steer[i]) + v.z * cos(_steer[i])) / wheel_radius * delta, -PI, PI)
		_wheels[i].basis = Basis(Vector3.RIGHT, _spin[i])


## Terrain normal across the whole footprint, from sample_height: smooth, and rocks underneath don't jerk the model.
func _ground_normal() -> Vector3:
	var t := TerrainGenerator.instance
	if t == null:
		return Vector3.UP
	var p := global_position
	var f := -global_basis.z * footprint.y
	var r := global_basis.x * footprint.x
	var ground := func(q: Vector3) -> Vector3: return Vector3(q.x, t.sample_height(q.x, q.z), q.z)
	return (ground.call(p + r) - ground.call(p - r)).cross(ground.call(p + f) - ground.call(p - f)).normalized()
