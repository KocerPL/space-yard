# Run: timeout -s KILL 60 godot --headless -s tests/test_poi.gd < /dev/null
extends SceneTree


func _initialize() -> void:
	root.add_child(load("res://scenes/terrain_sandbox.tscn").instantiate())
	await process_frame
	var t := TerrainGenerator.instance

	# nearest_rock is computed from the hash alone, so it must match a boulder the loaded chunk actually built.
	# Checked against the colliders: headless, MultiMesh transforms read back as zero.
	var rock: Transform3D = t.nearest_rock(Vector3(3, 0, 3))
	var chunk: Node3D = t.get_node("Chunk_%d_%d" % [floori(rock.origin.x / t.chunk_size), floori(rock.origin.z / t.chunk_size)])
	var built := false
	for cs: CollisionShape3D in chunk.find_children("*", "CollisionShape3D", false, false):
		built = built or (cs.shape is ConvexPolygonShape3D and chunk.to_global(cs.position).is_equal_approx(rock.origin))
	assert(built, "nearest_rock is a built boulder")

	var poi := Poi.new()
	poi.kind = Poi.Kind.ROCK
	poi.position = Vector3(3, 0, 3)
	root.add_child(poi)
	assert(poi.global_position.is_equal_approx(rock.origin), "rock POI snaps to the nearest boulder")
	var shell: MeshInstance3D = poi.find_children("*", "MeshInstance3D", false, false)[0]
	assert(shell.material_override is ShaderMaterial, "rock POI glows")
	assert(poi.find_child("Waystone", false, false) != null, "rock POI gets a waystone")

	var spot := Poi.new()
	spot.position = Vector3(-7, 50, 11)
	root.add_child(spot)
	assert(is_equal_approx(spot.global_position.y, t.sample_height(-7, 11)), "location POI sits on the ground")

	var hits := [0]
	poi.reached.connect(func() -> void: hits[0] += 1)
	var rover: Rover = root.find_child("Rover", true, false)
	var p := poi.global_position + Vector3(0, 0, 3)
	rover.global_position = Vector3(p.x, t.sample_height(p.x, p.z) + 0.5, p.z)
	for i in 5:
		await physics_frame
	assert(hits[0] > 0, "driving up to the POI emits reached")

	var compass := load("res://scripts/UI/compass.gd")
	assert(is_equal_approx(compass.heading(Vector3.FORWARD), 0.0), "-Z is north")
	assert(is_equal_approx(compass.heading(Vector3.RIGHT), 90.0), "+X is east")
	assert(is_equal_approx(compass.heading(Vector3.BACK), 180.0))
	assert(is_equal_approx(compass.heading(Vector3.LEFT), 270.0))
	print("poi OK")
	quit()
