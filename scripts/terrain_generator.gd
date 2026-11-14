class_name TerrainGenerator
extends Node3D
## Infinite streaming chunk terrain (Mars-like: dusty rolling plains, impact craters, rocky slopes).
## Chunks generate on the fly around every registered tracker (see register_tracker) and unload when
## far from all of them, so there is no world edge.

static var instance: TerrainGenerator

@export_group("Chunking")
## Cells per chunk side. Each chunk is a StaticBody3D with a mesh and a trimesh collider.
@export var chunk_size := 10
## Quads per chunk side; vertex spacing is chunk_size / resolution (m). Collision uses the same mesh.
@export var resolution := 20
## How many chunks out from each tracked node stay loaded (radius, in chunks).
@export var view_distance_in_chunks := 6
## Fallback focus, used only while no tracker is registered. Then the active camera, then the origin.
@export var track_target: Node3D
@export var chunk_update_interval := 0.5
## Caps how many new chunks generate per update tick, to avoid frame hitches.
@export var max_chunk_loads_per_update := 2

@export_group("Rendering")
## Defaults to a matte material that shows the vertex colors.
@export var terrain_material: Material
@export_flags_3d_physics var terrain_collision_layer := 1

@export_group("Craters (POI)")
## One crater slot per square cell of this size (m), jittered inside it. 0 = no craters.
## Keep it above 2 * (crater_radius * (1 + crater_radius_jitter) + crater_rim_width) or craters get cut at cell edges.
@export var crater_spacing := 40.0
## Fraction of cells that actually get a crater, so they don't sit on an obvious grid.
@export_range(0.0, 1.0) var crater_chance := 0.6
## Bowl radius, centre to rim crest (m).
@export var crater_radius := 7.0
@export_range(0.0, 0.5) var crater_radius_jitter := 0.5
## Bowl depth below the rim crest (m), scaled with each crater's radius.
@export var crater_depth := 3.0
## Rim crest height above the surrounding terrain (m), scaled with each crater's radius.
@export var crater_rim_height := 0.8
## Width of the outer rim slope back down to the plain (m).
@export var crater_rim_width := 5.0

@export_group("Noise")
@export var noise_seed := 42
@export var use_random_seed := false
@export var octaves := 6
@export var noise_scale := 60.0
@export var persistence := 0.45
@export var lacunarity := 2.0
@export var mesh_height_multiplier := 12.0
## Small-scale relief (bumps, ripples) added on top of the plains: amplitude in m, feature size in m.
@export var detail_amplitude := 0.35
@export var detail_size := 4.0

@export_group("Rocks")
## Rocks scattered per chunk, deterministic per seed. Most are pebbles; few are boulders.
@export var rocks_per_chunk := 12
## Smallest and largest rock size (m).
@export var rock_size := Vector2(0.08, 1.8)
## Higher = more small rocks, fewer boulders (size = lerp(min, max, rand^bias)).
@export var rock_size_bias := 4.0
## Rocks at least this big (m) get a collider; smaller ones are visual only.
@export var rock_collision_size := 0.5
## Defaults to a matte basalt material tinted per rock.
@export var rock_material: Material

@export_group("Colors")
## Color by height, sampled at 0..1 across color_height_range: dark basaltic sand in the lows,
## rust plains, pale dust on the highs. Blends smoothly between stops.
@export var height_colors := _default_height_colors()
## World heights (m) mapped to the 0 and 1 ends of height_colors.
@export var color_height_range := Vector2(-1.0, 13.0)
## Steepness (1 - normal.y) where bedrock starts showing through and where it fully takes over.
@export var rock_slope := Vector2(0.06, 0.22)
@export var rock_color := Color(0.27, 0.17, 0.12)
## Brightness variation from soft dust-patch noise.
@export_range(0.0, 0.3) var color_variation := 0.08

var _chunks: Dictionary[Vector2i, Node3D] = {}
var _trackers: Array[Node3D] = []
var _noise := FastNoiseLite.new()
var _color_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _rock_mesh: ArrayMesh
var _rock_points: PackedVector3Array # rock mesh vertices, for convex colliders
var _active_seed := 0
var _update_timer := 0.0


func _enter_tree() -> void:
	# A second generator would build its own overlapping chunk grid.
	if is_instance_valid(instance) and instance != self:
		push_warning("%s: another TerrainGenerator (%s) is active, disabling this one." % [name, instance.name])
		set_process(false)
		return
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if instance != self:
		return
	if terrain_material == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true # colors below are picked in sRGB
		m.roughness = 1.0
		terrain_material = m
	if rock_material == null:
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.36, 0.22, 0.15)
		rm.vertex_color_use_as_albedo = true # per-instance tint
		rm.vertex_color_is_srgb = true
		rm.roughness = 1.0
		rock_material = rm
	_build_rock_mesh()
	_init_seed()
	_refresh_chunks(true) # synchronous initial load so ground exists before anything spawns on it


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < chunk_update_interval:
		return
	_update_timer = 0.0
	_refresh_chunks(false)


func _init_seed() -> void:
	if use_random_seed:
		noise_seed = randi_range(0, 99999)
	_active_seed = noise_seed
	# Seeded noise replaces Unity's random offsets; frequency 1 + manual octaves keeps the original formula.
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.frequency = 1.0
	_noise.seed = noise_seed
	_color_noise.seed = noise_seed + 1
	_color_noise.frequency = 0.08
	_color_noise.fractal_octaves = 3
	_detail_noise.seed = noise_seed + 2
	_detail_noise.frequency = 1.0 / detail_size
	_detail_noise.fractal_octaves = 3
	var reach := _crater_reach()
	if crater_spacing > 0.0 and reach > crater_spacing * 0.5:
		push_warning("%s: craters reach %s m but cells are only %s m, craters will be cut at cell edges." % [name, reach, crater_spacing])


func regenerate_all_chunks() -> void:
	_init_seed()
	for chunk in _chunks.values():
		chunk.queue_free()
	_chunks.clear()
	_refresh_chunks(true)


func randomize_seed() -> void:
	use_random_seed = true
	regenerate_all_chunks()


## Rovers/creatures register themselves (_ready / _exit_tree) so terrain streams around every one of them.
func register_tracker(node: Node3D) -> void:
	if node != null and node not in _trackers:
		_trackers.append(node)


func unregister_tracker(node: Node3D) -> void:
	_trackers.erase(node)


## Synchronous, immediate load around a spot, for something that needs ground right now (e.g. snap to ground).
func ensure_loaded_around(world_pos: Vector3, radius_in_chunks: int) -> void:
	var center := _world_to_chunk(world_pos)
	for dz in range(-radius_in_chunks, radius_in_chunks + 1):
		for dx in range(-radius_in_chunks, radius_in_chunks + 1):
			var coord := center + Vector2i(dx, dz)
			if not _chunks.has(coord):
				_load_chunk(coord)


func _focus_position() -> Vector3:
	if is_instance_valid(track_target):
		return track_target.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


func _world_to_chunk(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / chunk_size), floori(p.z / chunk_size))


func _refresh_chunks(force: bool) -> void:
	_trackers = _trackers.filter(is_instance_valid) # prune freed nodes

	var foci: Array[Vector2i] = []
	if _trackers.is_empty():
		foci.append(_world_to_chunk(_focus_position()))
	else:
		for t in _trackers:
			foci.append(_world_to_chunk(t.global_position))

	var desired := {}
	for f in foci:
		for dz in range(-view_distance_in_chunks, view_distance_in_chunks + 1):
			for dx in range(-view_distance_in_chunks, view_distance_in_chunks + 1):
				desired[f + Vector2i(dx, dz)] = true

	for coord in _chunks.keys():
		if not desired.has(coord):
			_chunks[coord].queue_free()
			_chunks.erase(coord)

	var missing: Array[Vector2i] = []
	for coord in desired:
		if not _chunks.has(coord):
			missing.append(coord)
	if missing.is_empty():
		return

	# Closest-to-any-tracker first, so chunks near whichever tracker needs them most load first.
	missing.sort_custom(func(a, b): return _min_sqr_dist(a, foci) < _min_sqr_dist(b, foci))
	var count := missing.size() if force else mini(max_chunk_loads_per_update, missing.size())
	for i in count:
		_load_chunk(missing[i])


static func _min_sqr_dist(coord: Vector2i, foci: Array[Vector2i]) -> int:
	var best := 1 << 62
	for f in foci:
		best = mini(best, (coord - f).length_squared())
	return best


func _load_chunk(coord: Vector2i) -> void:
	var body := StaticBody3D.new()
	body.name = "Chunk_%d_%d" % [coord.x, coord.y]
	body.collision_layer = terrain_collision_layer
	body.position = Vector3(coord.x * chunk_size, 0.0, coord.y * chunk_size)

	var mesh := _build_chunk_mesh(coord)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_material
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape() # wheel/foot raycasts need a collider to hit
	body.add_child(shape)
	_scatter_rocks(body, coord)

	add_child(body)
	_chunks[coord] = body


## One lumpy, flat-shaded rock: a low-poly sphere pushed in/out by 3D noise. Variety comes from per-instance
## rotation, non-uniform scale and tint.
## ponytail: one base shape for every rock; build a few variants (different noise seeds) if repetition shows.
func _build_rock_mesh() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 9
	sphere.rings = 6
	var arrays := sphere.get_mesh_arrays()
	var lumps := FastNoiseLite.new()
	lumps.frequency = 2.0
	_rock_points = PackedVector3Array()
	for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		_rock_points.append(p * (1.0 + lumps.get_noise_3dv(p) * 0.6)) # by position, so seam duplicates stay joined
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # flat faces read as chipped rock
	for i: int in arrays[Mesh.ARRAY_INDEX]:
		st.add_vertex(_rock_points[i])
	st.generate_normals()
	_rock_mesh = st.commit()


func _scatter_rocks(body: StaticBody3D, coord: Vector2i) -> void:
	if rocks_per_chunk <= 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _rock_mesh
	mm.instance_count = rocks_per_chunk
	for i in rocks_per_chunk:
		var lx := _rock_rand(coord, i, 0) * chunk_size
		var lz := _rock_rand(coord, i, 1) * chunk_size
		var size := lerpf(rock_size.x, rock_size.y, pow(_rock_rand(coord, i, 2), rock_size_bias))
		var scl := size * Vector3(lerpf(0.7, 1.3, _rock_rand(coord, i, 3)), lerpf(0.45, 0.9, _rock_rand(coord, i, 4)),
			lerpf(0.7, 1.3, _rock_rand(coord, i, 5)))
		var rot := Basis.from_euler(Vector3(lerpf(-0.3, 0.3, _rock_rand(coord, i, 6)), _rock_rand(coord, i, 7) * TAU, 0.0))
		var basis := rot * Basis.from_scale(scl)
		var ground := sample_height(coord.x * chunk_size + lx, coord.y * chunk_size + lz)
		var origin := Vector3(lx, ground + scl.y * 0.2, lz) # ~30% buried, so they sit in the dust
		mm.set_instance_transform(i, Transform3D(basis, origin))
		var tint := lerpf(0.7, 1.15, _rock_rand(coord, i, 8))
		mm.set_instance_color(i, Color(tint, tint, tint))
		if size >= rock_collision_size:
			var convex := ConvexPolygonShape3D.new()
			convex.points = Transform3D(basis, Vector3.ZERO) * _rock_points # baked: colliders can't take non-uniform scale
			var cs := CollisionShape3D.new()
			cs.shape = convex
			cs.position = origin
			body.add_child(cs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rocks"
	mmi.multimesh = mm
	mmi.material_override = rock_material
	body.add_child(mmi)


func _rock_rand(coord: Vector2i, i: int, k: int) -> float:
	return _hash01(coord.x, coord.y, 100 + i * 10 + k)


## Smooth-shaded grid mesh with per-vertex colors (shared vertices, so colors and normals blend across quads).
func _build_chunk_mesh(coord: Vector2i) -> ArrayMesh:
	var r := resolution
	var step := float(chunk_size) / r
	var ox := float(coord.x * chunk_size)
	var oz := float(coord.y * chunk_size)
	# Heights at continuous world coordinates, with a one-vertex border so edge normals match the neighbour chunk.
	var w := r + 3
	var h := PackedFloat32Array()
	h.resize(w * w)
	for z in w:
		for x in w:
			h[z * w + x] = sample_height(ox + (x - 1) * step, oz + (z - 1) * step)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize((r + 1) * (r + 1))
	normals.resize(verts.size())
	colors.resize(verts.size())
	var k := 0
	for z in r + 1:
		for x in r + 1:
			var i := (z + 1) * w + x + 1
			# Central differences: normal of the continuous surface, identical on both sides of a chunk seam.
			var normal := Vector3(h[i - 1] - h[i + 1], 2.0 * step, h[i - w] - h[i + w]).normalized()
			verts[k] = Vector3(x * step, h[i], z * step)
			normals[k] = normal
			colors[k] = _surface_color(ox + x * step, oz + z * step, h[i], normal)
			k += 1

	var indices := PackedInt32Array()
	indices.resize(r * r * 6)
	k = 0
	for z in r:
		for x in r:
			var a := z * (r + 1) + x # (x, z)
			var b := a + 1 # (x+1, z)
			var c := a + r + 1 # (x, z+1)
			var d := c + 1 # (x+1, z+1)
			# Godot front faces are clockwise seen from above.
			for idx in [a, b, c, c, b, d]:
				indices[k] = idx
				k += 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Continuous terrain height at a world XZ (the generator sits at the origin): noise plains plus this cell's
## crater. Craters never reach past their own cell, so one cell is enough.
func sample_height(world_x: float, world_z: float) -> float:
	var height := _noise_height(world_x, world_z)
	if crater_spacing <= 0.0:
		return height
	var crater := _crater_in_cell(floori(world_x / crater_spacing), floori(world_z / crater_spacing))
	if crater.is_empty():
		return height
	var r: float = crater[1]
	var k := r / crater_radius # bigger craters are deeper with taller rims
	var d := Vector2(world_x, world_z).distance_to(crater[0]) / r
	var rim := crater_rim_height * k
	if d < 1.0:
		var q := 1.0 - d * d
		return height + rim - crater_depth * k * q * q # bowl with a flat floor and a rounded crest
	return height + rim * (1.0 - smoothstep(1.0, 1.0 + crater_rim_width / r, d)) # rim falls off to the plain


## POI: centres of the craters within radius (XZ) of center, at their floor height.
func craters_near(center: Vector3, radius: float) -> Array[Vector3]:
	var found: Array[Vector3] = []
	if crater_spacing <= 0.0:
		return found
	var c := Vector2(center.x, center.z)
	for x in range(floori((center.x - radius) / crater_spacing), floori((center.x + radius) / crater_spacing) + 1):
		for z in range(floori((center.z - radius) / crater_spacing), floori((center.z + radius) / crater_spacing) + 1):
			var crater := _crater_in_cell(x, z)
			if crater.is_empty():
				continue
			var p: Vector2 = crater[0]
			if p.distance_squared_to(c) <= radius * radius:
				found.append(Vector3(p.x, sample_height(p.x, p.y), p.y))
	return found


func _crater_reach() -> float:
	var r := crater_radius * (1.0 + crater_radius_jitter)
	return r + crater_rim_width


## [center: Vector2, radius: float] of a cell's crater, or [] if the cell has none.
## Jittered only as far as keeps the whole crater inside the cell.
func _crater_in_cell(cell_x: int, cell_z: int) -> Array:
	if _hash01(cell_x, cell_z, 3) >= crater_chance:
		return []
	var half := crater_spacing * 0.5
	var slack := maxf(0.0, half - _crater_reach())
	var radius := crater_radius * (1.0 + crater_radius_jitter * (_hash01(cell_x, cell_z, 2) * 2.0 - 1.0))
	var center := Vector2(
		cell_x * crater_spacing + half + (_hash01(cell_x, cell_z, 0) * 2.0 - 1.0) * slack,
		cell_z * crater_spacing + half + (_hash01(cell_x, cell_z, 1) * 2.0 - 1.0) * slack)
	return [center, radius]


## Deterministic 0..1 per (cell, salt) for the active seed. Bit-identical to the Unity version.
func _hash01(x: int, z: int, salt: int) -> float:
	const M := 0xFFFFFFFF
	var h := _mul32(_active_seed & M, 0x9E3779B1) ^ _mul32(x & M, 0x85EBCA77) \
		^ _mul32(z & M, 0xC2B2AE3D) ^ _mul32(salt & M, 0x27D4EB2F)
	h ^= h >> 15
	h = _mul32(h, 0x2C1B3C6D)
	h ^= h >> 12
	h = _mul32(h, 0x297A2D39)
	h ^= h >> 15
	return (h & 0xFFFFFF) / 16777216.0


## uint32 multiply without int64 overflow.
static func _mul32(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF


func _noise_height(world_x: float, world_z: float) -> float:
	var total := 0.0
	var amplitude := 1.0
	var frequency := 1.0
	var max_value := 0.0
	for i in octaves:
		var n := _noise.get_noise_2d(world_x / noise_scale * frequency, world_z / noise_scale * frequency) * 0.5 + 0.5
		total += n * amplitude
		max_value += amplitude
		amplitude *= persistence
		frequency *= lacunarity
	var normalized := clampf(total / max_value, 0.0, 1.0)
	return normalized * normalized * mesh_height_multiplier + _detail_noise.get_noise_2d(world_x, world_z) * detail_amplitude


func _surface_color(world_x: float, world_z: float, height: float, normal: Vector3) -> Color:
	var t := inverse_lerp(color_height_range.x, color_height_range.y, height)
	var color := height_colors.sample(clampf(t, 0.0, 1.0))
	color = color.lerp(rock_color, smoothstep(rock_slope.x, rock_slope.y, 1.0 - normal.y))
	color *= 1.0 + _color_noise.get_noise_2d(world_x, world_z) * color_variation
	color.a = 1.0
	return color


static func _default_height_colors() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	g.colors = PackedColorArray([Color(0.3, 0.17, 0.11), Color(0.52, 0.28, 0.16), Color(0.62, 0.36, 0.2),
		Color(0.7, 0.47, 0.3), Color(0.78, 0.6, 0.42)])
	return g
