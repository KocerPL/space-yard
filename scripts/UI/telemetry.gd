extends Control
## Top-left rover HUD: link speed, samples, and power. Power drains after the last voiced mission line.

var kiloByteCount = 0
@export_category("custom")
@export var kiloByteSpeedLimit = 27
## Mission transmission that starts the battery/solar drain.
@export var power_drain_trigger := "Battery low"
@export var power_drain_duration := 50.0
@export var battery_end := 0.0
@export var solar_end := 0.0

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
var _solar_start := 100.0


func _ready() -> void:
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
	_solar_start = solar


func _refresh_power_labels() -> void:
	batteryLevelLabel.text = "Battery: %.0f%%" % battery
	solarPowerLabel.text = "Solar power: %.0f W" % solar


func _process(delta: float) -> void:
	if _draining and power_drain_duration > 0.0:
		_drain_t += delta
		var u := clampf(_drain_t / power_drain_duration, 0.0, 1.0)
		# Ease-in so the drop accelerates as the storm kills the panels.
		var eased := u * u
		battery = lerpf(_battery_start, battery_end, eased)
		solar = lerpf(_solar_start, solar_end, eased)
		_refresh_power_labels()

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
	on_message_receive()


func _on_mission_event_started(event: MissionEvent) -> void:
	if event.transmission == power_drain_trigger:
		begin_power_drain()
