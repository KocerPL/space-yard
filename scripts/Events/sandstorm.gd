extends Node
@export_range(0.0, 1.0) var intensity := 0.0:
	set(v):
		intensity = clampf(v, 0.0, 1.0)
		_apply()
@onready var _world_env: WorldEnvironment = $"../WorldEnvironment"
@onready var _sun: DirectionalLight3D = $"../DirectionalLight3D"
func _ready() -> void:
	_apply()
func _apply() -> void:
	if not is_node_ready():
		return
	if _world_env == null or _sun == null:
		return
	var env := _world_env.environment
	if env == null:
		return
	env.fog_depth_begin = lerpf(25.0, 8.0, intensity)
	env.fog_depth_end = lerpf(62.0, 28.0, intensity)
	_sun.light_energy = lerpf(0.9, 0.25, intensity)
