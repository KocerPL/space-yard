# Run: timeout -s KILL 60 godot --headless -s tests/test_mission.gd < /dev/null
extends SceneTree


func _initialize() -> void:
	var world: Node = load("res://scenes/terrain_sandbox.tscn").instantiate()
	world.get_node("Mission").free() # replaced by a short one below
	root.add_child(world)
	await process_frame
	var rover: Rover = world.get_node("Rover")
	var poi: Poi = world.get_node("RockPoi")
	var dialog: Node = world.get_node("HUD/DialogBox")

	var beep := AudioStreamWAV.new()
	var data := PackedByteArray()
	data.resize(4410) # 0.1 s of 8-bit mono at 44.1 kHz
	beep.data = data

	var mission: Node = load("res://scripts/mission.gd").new() # loaded at runtime: the Audio autoload isn't declared yet when -s compiles this file
	mission.rover = rover
	mission.dialog = dialog
	mission.idle_after = 0.4
	var intro := _event("Intro", beep, 0.1)
	var at_poi := _event("Transmission 01", beep, 0.0)
	at_poi.poi = poi
	var idle := _event("Idle 01", beep, 0.0)
	idle.idle = true
	for e in [intro, at_poi, idle]:
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
	print("mission OK")
	quit()


func _event(key: String, voice: AudioStream, delay: float) -> MissionEvent:
	var e := MissionEvent.new()
	e.transmission = key
	e.voice = voice
	e.delay = delay
	return e
