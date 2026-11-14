extends Node

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

var master_volume: float = 1.0:
	set(value):
		master_volume = value
		_apply_volume()

func _ready() -> void:
	load_volume()

func save_volume() -> void:
	config.set_value("audio", "master_volume", master_volume)
	config.save(SAVE_PATH)

func load_volume() -> void:
	var err = config.load(SAVE_PATH)
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
	else:
		master_volume = 1.0 
	_apply_volume()

func _apply_volume() -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	var db = linear_to_db(master_volume)
	AudioServer.set_bus_volume_db(bus_idx, db)
