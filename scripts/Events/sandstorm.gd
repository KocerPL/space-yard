extends Node

@export_range(0.0, 1.0) var intensity := 0.0:
	set(v):
		intensity = clampf(v, 0.0, 1.0)
		_apply()

@export_range(0.0, 1.0) var lock_at := 0.85
@export_range(0.0, 1.0) var peak := 0.86
@export var ramp_up := 10.0
@export var hold := 10.0
@export var ramp_down := 10.0 # razem 30 s
@export var trigger_transmission := "Transmission 06"

@onready var _world_env: WorldEnvironment = $"../WorldEnvironment"
@onready var _sun: DirectionalLight3D = $"../DirectionalLight3D"
@onready var _rover: Rover = $"../Rover"
@onready var _mission: Mission = $"../Mission"
@onready var _dust_follow: Node3D = $DustFollow
@onready var _dust: GPUParticles3D = $DustFollow/Dust

var _tween: Tween

func _ready() -> void:
	if _dust:
		_dust.emitting = false
	_apply()
	_mission.event_started.connect(_on_event_started)

func begin() -> void:
	if _tween:
		_tween.kill()
	intensity = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "intensity", peak, ramp_up)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "intensity", 0.0, ramp_down)

func _on_event_started(event: MissionEvent) -> void:
	if event.transmission == trigger_transmission:
		begin()

func _process(_delta: float) -> void:
	if _dust_follow and _rover:
		_dust_follow.global_position = _rover.get_global_transform_interpolated().origin + Vector3.UP * 1.0

func _apply() -> void:
	if not is_node_ready():
		return
	if _world_env == null or _sun == null:
		return
	var env := _world_env.environment
	if env == null:
		return

	env.fog_depth_begin = lerpf(25.0, 1.0, intensity)
	env.fog_depth_end = lerpf(62.0, 6.0, intensity)
	env.fog_light_color = Color(0.74, 0.54, 0.4).lerp(Color(0.04, 0.03, 0.02), intensity)
	env.fog_sky_affect = lerpf(0.0, 1.0, intensity)
	env.background_energy_multiplier = lerpf(1.0, 0.05, intensity)
	env.ambient_light_energy = lerpf(0.45, 0.0, intensity)
	_sun.light_energy = lerpf(0.9, 0.0, intensity)
	
	var sky_mat := env.sky.sky_material as ShaderMaterial
	if sky_mat:
		sky_mat.set_shader_parameter("brightness", lerpf(1.0, 0.08, intensity))
		sky_mat.set_shader_parameter("dust", lerpf(0.0, 0.85, intensity))

	if _rover:
		_rover.is_stopped = intensity >= lock_at

	if _dust:
		_dust.emitting = intensity > 0.05
		_dust.amount_ratio = clampf(intensity / maxf(peak, 0.001), 0.0, 1.0)
