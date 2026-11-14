extends Control
## Top-left rover HUD: link speed, samples, and power.
## Solar tracks sandstorm intensity; battery drains after "Battery low".

var kiloByteCount = 0
@export_category("custom")
@export var kiloByteSpeedLimit = 27
## Mission transmission that starts the battery drain.
@export var power_drain_trigger := "Battery low"
@export var power_drain_duration := 40.0
@export var battery_end := 0.0
@export var solar_end := 0.0
## Epilogue lines: TX/RX stay frozen (link is dead).
@export var freeze_net_transmissions: PackedStringArray = [
	"Only silence",
	"No response",
	"Collected data",
	"Goodbye Oppy",
]
## Optional; if empty, looks up Sandstorm on the current scene.
@export var sandstorm_path: NodePath

@onready var foundSamplesLabel = $PanelContainer/MarginContainer/VBoxContainer/FoundSamplesLabel
@onready var netSpeedLabel = $PanelContainer/MarginContainer/VBoxContainer/NetSpeedLabel
@onready var batteryLevelLabel = $PanelContainer/MarginContainer/VBoxContainer/BatteryLabel
@onready var solarPowerLabel = $PanelContainer/MarginContainer/VBoxContainer/SolarPowerLabel

var nextCheck := 0.0
var battery := 100.0
var solar := 100.0
var _draining := false
var _drain_t := 0.0
var _battery_start := 100.0
var _link_frozen := false
## Untyped: Sandstorm has no class_name; we only read intensity/peak.
var _sandstorm


func _ready() -> void:
	if sandstorm_path:
		_sandstorm = get_node_or_null(sandstorm_path)
	else:
		var scene := get_tree().current_scene
		if scene:
			_sandstorm = scene.get_node_or_null("Sandstorm")
	_refresh_power_labels()


func on_message_receive() -> void:
	kiloByteCount = 300


func set_battery_level(batteryLevel: float) -> void:
	battery = batteryLevel
	_refresh_power_labels()


func set_solar_power(solarPowerWatts: float) -> void:
	solar = solarPowerWatts
	_refresh_power_labels()


func begin_power_drain() -> void:
	if _draining:
		return
	_draining = true
	_drain_t = 0.0
	_battery_start = battery


func _freeze_net() -> void:
	_link_frozen = true
	kiloByteCount = 0
	netSpeedLabel.text = "TX: 0 kB/s\nRX: 0 kB/s"


func _refresh_power_labels() -> void:
	batteryLevelLabel.text = "Battery: %.0f%%" % battery
	solarPowerLabel.text = "Solar power: %.0f W" % solar


func _process(delta: float) -> void:
	var power_changed := false

	if _sandstorm and is_instance_valid(_sandstorm):
		var u_solar := clampf(_sandstorm.intensity / maxf(_sandstorm.peak, 0.001), 0.0, 1.0)
		var next_solar: float = lerpf(100.0, solar_end, u_solar)
		if not is_equal_approx(next_solar, solar):
			solar = next_solar
			power_changed = true

	if _draining and power_drain_duration > 0.0:
		_drain_t += delta
		var u := clampf(_drain_t / power_drain_duration, 0.0, 1.0)
		# Ease-in so the drop accelerates as systems fail.
		var eased := u * u
		battery = lerpf(_battery_start, battery_end, eased)
		power_changed = true

	if power_changed:
		_refresh_power_labels()

	if _link_frozen:
		return

	nextCheck -= delta
	if nextCheck <= 0:
		nextCheck = 1
		var currentSpeedLimit: float = kiloByteSpeedLimit + randf_range(-kiloByteSpeedLimit / 2.0, kiloByteSpeedLimit / 2.0)
		netSpeedLabel.text = "TX: %d kB/s\nRX: %d kB/s" % [
			mini(kiloByteCount, int(currentSpeedLimit)),
			maxi(0, mini(kiloByteCount, int(kiloByteSpeedLimit + randf_range(-kiloByteSpeedLimit / 2.0, kiloByteSpeedLimit / 2.0)))),
		]
		if kiloByteCount > 0:
			kiloByteCount = maxi(0, kiloByteCount - int(currentSpeedLimit))


func _on_mission_reading_message() -> void:
	if _link_frozen:
		return
	on_message_receive()


func _on_mission_event_started(event: MissionEvent) -> void:
	if event.transmission in freeze_net_transmissions:
		_freeze_net()
	if event.transmission == power_drain_trigger:
		begin_power_drain()
