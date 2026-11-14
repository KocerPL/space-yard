# Run: godot --headless -s tests/test_terrain_generator.gd
extends SceneTree


func _initialize() -> void:
	var t := TerrainGenerator.new()
	t.view_distance_in_chunks = 1
	root.add_child(t)
	await process_frame # _ready runs once the main loop starts

	# Cell hash is bit-identical to the Unity C# version (values from a uint32 reference).
	assert(is_equal_approx(t._hash01(0, 0, 0), 0.1280517578125))
	assert(is_equal_approx(t._hash01(-3, 7, 1), 0.9223008751869202))
	assert(is_equal_approx(t._hash01(123, -45, 2), 0.30466747283935547))

	assert(t.get_child_count() == 9, "3x3 chunks around origin")
	var mesh: ArrayMesh = t.get_child(0).get_child(0).mesh
	for n in mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
		assert(n.y > 0.0, "terrain faces up")

	# Seam: the shared edge of neighbouring chunks has identical heights and normals (no visible crease).
	var left: Array = t.get_node("Chunk_0_0").get_child(0).mesh.surface_get_arrays(0)
	var right: Array = t.get_node("Chunk_1_0").get_child(0).mesh.surface_get_arrays(0)
	var row := t.resolution + 1
	for z in row:
		var li := z * row + t.resolution
		var ri := z * row
		assert(is_equal_approx(left[Mesh.ARRAY_VERTEX][li].y, right[Mesh.ARRAY_VERTEX][ri].y))
		assert(left[Mesh.ARRAY_NORMAL][li].is_equal_approx(right[Mesh.ARRAY_NORMAL][ri]))

	# Crater: floor below the plain, rim crest above it.
	var craters := t.craters_near(Vector3.ZERO, 200.0)
	assert(not craters.is_empty())
	var c: Vector3 = craters[0]
	var crater: Array = t._crater_in_cell(floori(c.x / t.crater_spacing), floori(c.z / t.crater_spacing))
	var r: float = crater[1]
	var plain := t._noise_height(c.x, c.z)
	assert(t.sample_height(c.x, c.z) < plain - 1.0, "crater floor is sunk")
	assert(t.sample_height(c.x + r, c.z) > t._noise_height(c.x + r, c.z), "rim is raised")
	var far := c.x + r + t.crater_rim_width + 0.1
	assert(is_equal_approx(t.sample_height(far, c.z), t._noise_height(far, c.z)), "rim blends back to the plain")

	await physics_frame
	await physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(5.5, 100, 5.5), Vector3(5.5, -100, 5.5))
	assert(not root.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "raycast from above hits terrain")
	print("terrain_generator OK")
	quit()
