extends Node
## 29.5 s showcase reel: the sandbox world with no HUD or mission. The rover drives itself to the glowing rock,
## samples it with the arm, turns away and parks as the dust storm swallows it, then the title shows.
## Record it with Movie Maker (it quits at `length`). Movie Maker's frame size is the project's base viewport size, so
## override that to `resolution` for the run only (override.cfg rescales every scene's UI, don't leave it in):
##   printf '[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\n' > override.cfg
##   godot --write-movie showcase.avi scenes/showcase.tscn; rm override.cfg
## Times below are seconds from the start, cut on the pauses in the Voiceover clip (showcase.mp3): retime them if it changes.

const SANDBOX := preload("res://scenes/terrain_sandbox.tscn")

@export var length := 29.5
## Game music level under the voiceover, dB.
@export var music_db := -20.0
## Rendered at this size whatever the window is. Keep it equal to the Movie Maker size above.
@export var resolution := Vector2i(1920, 1080)

var _time := 0.0
var _cam_tween: Tween

@onready var _title: CanvasItem = $Title/Center

var rover: Rover
var rig # CameraRig and Sandstorm are untyped scripts
var spring: SpringArm3D
var storm


func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = resolution
	var world := SANDBOX.instantiate()
	world.get_node("Mission").free() # before entering the tree, so no transmission or HUD ever starts
	world.get_node("HUD").free()
	world.get_node("CraterPoi").hide() # one beacon, the rock's, is enough
	rover = world.get_node("Rover")
	rover.autopilot = true
	rover.speed = 1.8 # unhurried, reads better on camera
	rover.position.x = 1.5 # from the sandbox spawn the straight line to the rock clips a boulder
	rig = world.get_node("CameraRig")
	rig.intro_distance = 45.0
	rig.intro_time = 5.2 # done before the 5.7 s cut takes the spring arm
	spring = rig.get_node("SpringArm3D")
	spring.spring_length = 6.5
	storm = world.get_node("Sandstorm")
	storm.ramp_up = 6.0
	add_child(world)
	_title.modulate.a = 0.0
	AudioServer.set_bus_volume_db(0, 0.0) # the reel's own mix, not the player's saved master volume (left unsaved)
	$Voiceover.play()
	var music := get_node("/root/MusicPlayer")
	music.set_target_volume(music_db) # its _process eases both tracks towards this
	for track in [music.get_node("MainTrack"), music.get_node("TenseTrack")]:
		track.volume_db = music_db
	_camera()
	_drive(world.get_node("RockPoi"))


func _process(delta: float) -> void:
	_time += delta


func _camera() -> void:
	# 0: establishing, the rig zooms in from intro_distance while the camera swings round the front
	_shot(155, -22, 0, 1.0)
	_shot(115, -14, 0, 1.0, 5.7)
	# 5.7: low tracking shot along the side, rocker-bogie at work
	await _at(5.7)
	_shot(80, 5, 4.5, 0.8)
	_shot(45, 2, 4.0, 0.8, 4.4)
	# 10.1: close on the arm at the rock
	await _at(10.1)
	_shot(-115, -12, 3.6, 0.35) # front left, the arm's side
	_shot(-95, -10, 3.0, 0.35, 8.4)
	# 18.5: crane up and out as it drives on
	await _at(18.5)
	_shot(20, -38, 15.0, 1.0, 5.9)
	await _at(21.2)
	storm.begin()
	get_node("/root/MusicPlayer").play_tense_track()
	# 24.4: drift in on the parked rover as the storm closes over it
	await _at(24.4)
	_shot(-10, -26, 10.0, 1.0, 5.1)
	await _at(26.4)
	create_tween().tween_property(_title, "modulate:a", 1.0, 2.0)
	await _at(length)
	if OS.has_feature("movie"):
		get_tree().quit() # Movie Maker writes the file on quit


func _drive(rock_poi: Node3D) -> void:
	var rock: Transform3D = TerrainGenerator.instance.nearest_rock(rock_poi.global_position) # the boulder it glows on
	var s := rock.basis.get_scale()
	var radius := maxf(s.x, s.z) * 0.8 # lumps reach ~0.8 of a rock's scale, see poi.gd
	await _drive_to(rock.origin, radius + 1.5, 11.0) # it rolls on ~0.4 m while braking
	var side := rover.global_position - rock.origin
	side.y = 0.0
	var arm: RoverArm = rover.get_node("Arm")
	arm.reach(rock.origin + side.normalized() * radius * 0.85 + Vector3.UP * s.y * 0.3)
	await _at(15.8)
	arm.stow()
	await _at(17.3)
	rock_poi.hide() # sampled, as the mission hides a reached POI
	await _at(18.5)
	rover.drive_input = Vector2(0.0, -1.0) # turn right on the spot, off the rock: the corner wheels swing round
	await _at(19.5)
	rover.drive_input = Vector2(1.0, 0.0)
	await _at(24.4)
	rover.drive_input = Vector2.ZERO # parks before the storm would lock it


## Steers at p until within stop_at metres or the clock reaches until, then stops.
func _drive_to(p: Vector3, stop_at: float, until: float) -> void:
	while _time < until:
		var to := p - rover.global_position
		to.y = 0.0
		if to.length() < stop_at:
			break
		var off := (-rover.global_basis.z).signed_angle_to(to, Vector3.UP)
		rover.drive_input = Vector2(1.0, clampf(off * 2.0, -1.0, 1.0))
		await get_tree().physics_frame
	rover.drive_input = Vector2.ZERO


## Points the camera at yaw (degrees from behind the rover, positive to its right), pitch (negative looks down),
## dist (0 leaves the spring arm alone) and height above the rover. Cuts if time is 0, else moves over time.
func _shot(yaw: float, pitch: float, dist: float, height: float, time := 0.0) -> void:
	var y := rover.rotation.y + deg_to_rad(yaw)
	var rot := Vector3(deg_to_rad(pitch), rig.rotation.y + wrapf(y - rig.rotation.y, -PI, PI), 0.0) # the short way round
	if _cam_tween:
		_cam_tween.kill()
	if time == 0.0:
		rig.rotation = rot
		rig.height = height
		if dist > 0.0:
			spring.spring_length = dist
		return
	_cam_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(rig, "rotation", rot, time)
	_cam_tween.tween_property(rig, "height", height, time)
	if dist > 0.0:
		_cam_tween.tween_property(spring, "spring_length", dist, time)


func _at(t: float) -> void:
	while _time < t:
		await get_tree().process_frame
