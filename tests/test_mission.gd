# Run: timeout -s KILL 60 godot --headless -s tests/test_mission.gd < /dev/null
extends SceneTree


func _initialize() -> void:
	var world: Node = load("res://scenes/terrain_sandbox.tscn").instantiate()
	world.get_node("Mission").free() # replaced by a short one below
	root.add_child(world)
	# The scene's first frames are slow (synchronous terrain load, shader compiles), and their long delta would run the
	# short test timers out in one step. Let it settle before the timed part starts.
	for i in 10:
		await process_frame
	var rover: Rover = world.get_node("Rover")
	var poi: Poi = world.get_node("RockPoi")
	var dialog: Node = world.get_node("HUD/DialogBox")

	var beep := AudioStreamWAV.new()
	var data := PackedByteArray()
	data.resize(4410) # 0.1 s of 8-bit mono at 44.1 kHz
	beep.data = data

	var mission := Mission.new()
	mission.rover = rover
	mission.dialog = dialog
	mission.idle_after = 0.4
	var intro := _event("Intro", beep, 0.1)
	var at_poi := _event("Transmission 01", beep, 0.0)
	at_poi.poi = poi
	var idle := _event("Idle 01", beep, 0.0)
	idle.idle = true
	var crater: Poi = world.get_node("CraterPoi")
	var prompt := Label.new()
	world.add_child(prompt)
	var sample := Label.new()
	sample.hide()
	world.add_child(sample)
	var analyzing := Label.new()
	analyzing.hide()
	world.add_child(analyzing)
	mission.prompt = prompt
	mission.analyzing = analyzing
	mission.analyze_time = 0.2
	var analysis: Array[String] = []
	mission.analysis_started.connect(func(e: MissionEvent) -> void: analysis.append("started " + e.transmission))
	mission.analysis_finished.connect(func(e: MissionEvent) -> void: analysis.append("finished " + e.transmission))
	var analyzed := _event("Transmission 03", beep, 0.0)
	analyzed.poi = crater
	analyzed.analyze = true
	analyzed.sample = sample
	for e in [intro, at_poi, analyzed, idle]:
		mission.add_child(e)
	var started: Array[String] = []
	mission.event_started.connect(func(e: MissionEvent) -> void: started.append(e.transmission))
	world.add_child(mission)
	assert(not poi.visible, "a POI stays hidden until it's the target")

	await create_timer(0.15).timeout
	assert(started == ["Intro"], "the first event plays after its delay: %s" % [started])
	assert(dialog.background.visible, "with its text")
	await create_timer(0.3).timeout
	assert(not dialog.background.visible, "the text closes when the voice ends")
	assert(poi.visible, "the next event's POI shows once it's the target")

	await create_timer(0.6).timeout
	assert("Idle 01" in started, "standing still plays an idle transmission: %s" % [started])
	assert("Transmission 01" not in started, "an event with a POI waits for the rover")

	var p := poi.global_position + Vector3(0, 0, 2)
	rover.global_position = Vector3(p.x, TerrainGenerator.instance.sample_height(p.x, p.z) + 0.5, p.z)
	await create_timer(0.4).timeout
	assert(started.back() == "Transmission 01", "reaching the POI plays its transmission: %s" % [started])
	assert(not poi.visible, "and hides the reached POI")

	mission.idle_after = 100.0 # keep idle transmissions out of the analysis checks
	await create_timer(0.2).timeout # Transmission 01's beep ends
	p = crater.global_position + Vector3(0, 0, 2)
	rover.global_position = Vector3(p.x, TerrainGenerator.instance.sample_height(p.x, p.z) + 0.5, p.z)
	await create_timer(0.3).timeout
	assert(prompt.visible, "an analyze event's POI shows the prompt")
	assert("Transmission 03" not in started, "and waits for E: %s" % [started])
	_key_e(true)
	await process_frame
	await process_frame
	_key_e(false)
	assert(rover.is_stopped, "E stops the rover to analyze")
	assert(not prompt.visible, "and hides the prompt")
	assert(analyzing.visible, "the analyzing label shows during the analysis")
	assert(analysis == ["started Transmission 03"], "analysis_started fires for the arm animation: %s" % [analysis])
	assert("Transmission 03" not in started, "the transmission waits for the analysis")
	await create_timer(0.35).timeout
	assert(started.back() == "Transmission 03", "the analysis ends with the transmission: %s" % [started])
	assert(sample.visible, "and shows the sample")
	assert(not rover.is_stopped, "and frees the rover")
	assert(not analyzing.visible, "and hides the analyzing label")
	assert(analysis.back() == "finished Transmission 03", "analysis_finished fires: %s" % [analysis])
	print("mission OK")
	quit()


func _key_e(pressed: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = KEY_E
	k.pressed = pressed
	Input.parse_input_event(k)


func _event(key: String, voice: AudioStream, delay: float) -> MissionEvent:
	var e := MissionEvent.new()
	e.transmission = key
	e.voice = voice
	e.delay = delay
	return e
