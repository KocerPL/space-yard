# Run: timeout -s KILL 60 godot --headless -s tests/test_rover.gd < /dev/null
extends SceneTree


func _initialize() -> void:
	root.add_child(load("res://scenes/terrain_sandbox.tscn").instantiate())
	var rover: Rover = root.find_child("Rover", true, false)
	for i in 60:
		await physics_frame
	assert(rover.is_on_floor(), "rover lands on the terrain")
	var start := rover.global_position
	var fwd := -rover.global_basis.z

	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	for i in 60:
		await physics_frame
	assert((rover.global_position - start).dot(fwd) > 1.0, "W drives forward")

	assert(rover._spin[1] != 0.0, "driving spins the wheels")

	w.pressed = false
	Input.parse_input_event(w)
	for i in 60: # coast to a stop so the turn below is in place
		await physics_frame
	var yaw := rover.rotation.y
	var a := InputEventKey.new()
	a.physical_keycode = KEY_A
	a.pressed = true
	Input.parse_input_event(a)
	for i in 30:
		await physics_frame
	assert(rover.rotation.y > yaw + 0.3, "A turns left")
	# turning in place swings the front corner wheels tangent to the turn, toes pointing inward
	assert(rover._steer[0] < -0.3 and rover._steer[3] > 0.3, "corner wheels steer into the turn: %s" % rover._steer)

	# suspension kinematics: with the ground offsets given, every wheel ends up on its ground
	rover.set_physics_process(false)
	rover._ground = PackedFloat32Array([0.08, 0.0, -0.05, -0.04, 0.06, 0.02])
	rover._pose_suspension()
	for i in 6:
		var off: float = rover._model.to_local(rover._wheels[i].global_position).y - rover._rest[i].y
		assert(absf(off - rover._ground[i]) < 0.02, "wheel %s sits on its ground: %.3f vs %.3f" % [Rover.WHEELS[i], off, rover._ground[i]])
	print("rover OK")
	quit()
