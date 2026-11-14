extends Control
var kiloByteCount = 0;
@export_category("custom")
@export var kiloByteSpeedLimit = 27;
@onready var foundSamplesLabel = $PanelContainer/MarginContainer/VBoxContainer/FoundSamplesLabel
@onready var netSpeedLabel =  $PanelContainer/MarginContainer/VBoxContainer/NetSpeedLabel
@onready var batteryLevelLabel = $PanelContainer/MarginContainer/VBoxContainer/BatteryLabel
@onready var solarPowerLabel = $PanelContainer/MarginContainer/VBoxContainer/SolarPowerLabel
var nextCheck=0;

func on_message_receive()-> void:
	kiloByteCount= 300;
func set_battery_level(batteryLevel:float):
	batteryLevelLabel.text = "Battery: %f%"% [batteryLevel]
func set_solar_power(solarPowerWatts:float):
	solarPowerLabel.text = "Solar power: %f W"% [solarPowerWatts]
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	nextCheck-=delta;
	if nextCheck<=0:
		nextCheck =1;
		var currentSpeedLimit = kiloByteSpeedLimit+randf_range(-kiloByteSpeedLimit/2,kiloByteSpeedLimit/2)
		netSpeedLabel.text = "TX: %d kB/s\nRX: %d kB/s" % [min(kiloByteCount,currentSpeedLimit),max(0,min(kiloByteCount,kiloByteSpeedLimit+randf_range(-kiloByteSpeedLimit/2,kiloByteSpeedLimit/2)))]
		if(kiloByteCount>0):
			kiloByteCount=max(0,kiloByteCount- currentSpeedLimit);
		
	pass


func _on_mission_reading_message() -> void:
	on_message_receive()
	pass # Replace with function body.
