# Run: timeout -s KILL 60 godot --headless -s tests/test_rover_arm.gd < /dev/null
extends SceneTree


func _initialize() -> void:
	var rover: Rover = load("res://prefabs/rover.tscn").instantiate()
	root.add_child(rover)
	await process_frame
	rover.set_physics_process(false) # no terrain here: keep it from falling while the arm moves
	var arm: RoverArm = rover.get_node("Arm")
	var body: MeshInstance3D = rover.get_node("Model/Body")
	for i in body.mesh.get_surface_count():
		assert(body.mesh.surface_get_name(i) != "tex_arm", "the arm is cut out of the body")
	assert(arm.tip().is_equal_approx(body.to_global(RoverArm.TIP)), "stowed, the arm is where the model has it")
	var turret: MeshInstance3D = arm._joints[2].get_child(0)
	assert((turret.global_transform * turret.get_aabb()).grow(0.01).has_point(arm.tip()), "the turret mesh sits on its tip")

	var target := body.to_global(RoverArm.SHOULDER + Vector3(0.1, -0.25, 0.45)) # ahead and below, in reach
	arm.reach(target)
	await create_timer(arm.unfold_time + 0.3).timeout
	assert(arm.tip().distance_to(target) < 0.005, "the tip reaches the target")

	arm.reach(body.to_global(Vector3(0, 0, -5))) # behind the rover and out of reach
	await create_timer(arm.unfold_time + 0.3).timeout
	assert(body.to_local(arm.tip()).z > RoverArm.SHOULDER.z, "never reaches back through the body")

	arm.stow()
	await create_timer(arm.unfold_time + 0.3).timeout
	assert(arm.tip().is_equal_approx(body.to_global(RoverArm.TIP)), "stow folds it back")

	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	Input.parse_input_event(e)
	await create_timer(arm.unfold_time + 0.2).timeout
	assert(body.to_local(arm.tip()).z > RoverArm.TIP.z + 0.3, "E reaches out ahead")
	e.pressed = false
	Input.parse_input_event(e)
	await create_timer(arm.hold_time + arm.unfold_time + 0.3).timeout
	assert(arm.tip().is_equal_approx(body.to_global(RoverArm.TIP)), "then folds back by itself")
	print("rover_arm OK")
	quit()
