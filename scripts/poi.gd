class_name Poi
extends Area3D
## Point of interest for the rover: a spot on the ground, or the nearest boulder, which then glows.
## Either way a waystone with a light beam stands there, visible past the fog. Must come after the
## TerrainGenerator in the tree, since it snaps to the ground in _ready.

signal reached

enum Kind { LOCATION, ROCK }

const WAYSTONE := preload("res://prefabs/waystone.tscn")
const HIGHLIGHT := preload("res://assets/shaders/poi_highlight.gdshader")

## LOCATION snaps to the ground under this node; ROCK snaps to the nearest boulder.
@export var kind := Kind.LOCATION
## reached fires when the rover comes within this distance (m).
@export var radius := 4.0


func _ready() -> void:
	collision_layer = 0 # only detects, nothing should hit it
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = radius
	add_child(shape)
	body_entered.connect(func(body: Node3D) -> void: if body is Rover: reached.emit())

	var t := TerrainGenerator.instance
	if t == null:
		push_warning("%s: no TerrainGenerator, POI left where it is." % name)
		return
	var stone_at := global_position
	var rock: Variant = t.nearest_rock(global_position) if kind == Kind.ROCK else null
	if kind == Kind.ROCK and rock == null:
		push_warning("%s: no boulder near %s, marking the spot instead." % [name, global_position])
	if rock != null:
		global_position = rock.origin
		var shell := MeshInstance3D.new()
		shell.mesh = t.rock_mesh
		shell.material_override = ShaderMaterial.new()
		shell.material_override.shader = HIGHLIGHT
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shell)
		shell.global_transform = Transform3D(rock.basis * 1.08, rock.origin)
		var s: Vector3 = rock.basis.get_scale()
		stone_at = rock.origin + Vector3(maxf(s.x, s.z) * 0.8 + 0.4, 0.0, 0.0) # beside the rock: lumps reach ~0.8 of its scale
	else:
		global_position.y = t.sample_height(global_position.x, global_position.z)
	var stone := WAYSTONE.instantiate()
	add_child(stone)
	stone.global_position = Vector3(stone_at.x, t.sample_height(stone_at.x, stone_at.z), stone_at.z)
	reset_physics_interpolation() # moved, don't interpolate from the old spot
