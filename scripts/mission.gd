class_name Mission
extends Node
## Event system: plays its MissionEvent children in tree order. Each waits its delay after the previous one ends
## and, if it has a POI, until the rover is inside it. Idle events fill in while the rover stands still.
## A transmission shows its lines in the dialog box, paced to its voice clip.

signal event_started(event: MissionEvent)
signal reading_message
## An analyze event's analysis begins and ends. Hook an arm animation here; set analyze_time to its length.
signal analysis_started(event: MissionEvent)
signal analysis_finished(event: MissionEvent)
@export var rover: Rover
## A scenes/UI/dialog_box.tscn whose text_file holds the transmissions.
@export var dialog: Node
## Seconds of standing still before an idle transmission. Idle events take turns.
@export var idle_after := 45.0
## Characters per second, for how long text without a voice clip stays up.
@export var read_speed := 15.0
## Shown while the rover is at an analyze event's POI, e.g. "Press [E] to collect sample".
@export var prompt: Control
## Shown while the analysis runs, e.g. "Analyzing sample...".
@export var analyzing: Control
## Seconds the rover stands still analyzing after E.
@export var analyze_time := 4.0
## Scene to switch to once the last event in the sequence has played. Empty keeps the current scene.
@export_file("*.tscn") var end_scene := ""
## Seconds after the last event before switching to end_scene.
@export var end_delay := 5.0

var _events: Array[MissionEvent] = []
var _idle: Array[MissionEvent] = []
var _next := 0
var _waited := 0.0
var _still := 0.0
var _busy := false
var _e_was := false
## The Audio autoload, looked up instead of named: naming it doesn't compile where autoloads aren't declared
## (-s scripts, or an editor opened before the autoload was added).
@onready var _audio: Node = get_node("/root/Audio")


func _ready() -> void:
	for e: MissionEvent in get_children():
		(_idle if e.idle else _events).append(e)
		if e.poi:
			e.poi.hide()


func _exit_tree() -> void:
	_audio.stop_voice() # Audio outlives the scene


func _process(delta: float) -> void:
	# raw physical key, like the rover's drive keys; tracked every frame so a held E doesn't count later
	var e_down := Input.is_physical_key_pressed(KEY_E)
	var e_pressed := e_down and not _e_was
	_e_was = e_down
	if _busy or _next >= _events.size():
		return
	var e := _events[_next]
	if e.poi:
		e.poi.show()
	_waited += delta
	var arrived := _waited >= e.delay and (e.poi == null or e.poi.overlaps_body(rover))
	if e.analyze and prompt:
		prompt.visible = arrived
	if arrived and (not e.analyze or e_pressed):
		_next += 1
		_waited = 0.0
		_still = 0.0
		if e.analyze:
			_analyze(e)
		else:
			_play(e)
		return
	_still = _still + delta if Vector2(rover.velocity.x, rover.velocity.z).length() < 0.1 else 0.0
	if _still >= idle_after and not _idle.is_empty():
		_still = 0.0
		if prompt:
			prompt.hide() # back once the idle transmission is over, if the rover is still at the POI
		var idle: MissionEvent = _idle.pop_front()
		_idle.append(idle)
		_play(idle)


## E at an analyze event's POI: the rover stands still for analyze_time, the sample shows, then the event plays.
func _analyze(e: MissionEvent) -> void:
	_busy = true
	if prompt:
		prompt.hide()
	e.poi.hide()
	rover.is_stopped = true
	if analyzing:
		analyzing.show()
	analysis_started.emit(e)
	await get_tree().create_timer(analyze_time).timeout
	if analyzing:
		analyzing.hide()
	analysis_finished.emit(e)
	rover.is_stopped = false
	if e.sample:
		e.sample.show()
	_play(e)


func _play(e: MissionEvent) -> void:
	_busy = true
	event_started.emit(e)
	if e.poi:
		e.poi.hide()
	var lines: Array = dialog.scene_text.get(e.transmission, [])
	if lines.is_empty():
		push_warning("%s: no lines for transmission '%s'." % [e.name, e.transmission])
	var chars := 0
	for line: String in lines:
		chars += line.length()
	var length := e.voice.get_length() if e.voice else chars / read_speed
	if e.voice:
		_audio.play_voice(e.voice)
	if lines.is_empty():
		await get_tree().create_timer(length).timeout
	else:
		dialog.start_dialog(e.transmission)
		
		for line: String in lines: # each line stays up for its share of the clip; the last next_line closes the box
			reading_message.emit();
			await get_tree().create_timer(length * line.length() / maxi(chars, 1)).timeout
			dialog.next_line()
	if not e.idle and _next >= _events.size() and end_scene: # the mission is over; _process stays idle from here
		await get_tree().create_timer(end_delay).timeout
		get_tree().change_scene_to_file(end_scene)
		return
	_busy = false
