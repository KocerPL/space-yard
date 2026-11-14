extends Control
var byteCount = 100;
@export_category("custom")
@export var byteSpeedLimit = 10;
@onready var foundSamplesLabel = $PanelContainer/MarginContainer/VBoxContainer/FoundSamplesLabel
@onready var netSpeedLabel =  $PanelContainer/MarginContainer/VBoxContainer/NetSpeedLabel
@onready var batteryLevelLabel = $PanelContainer/MarginContainer/VBoxContainer/BatteryLabel
@onready var solarPowerLabel = $PanelContainer/MarginContainer/VBoxContainer/SolarPowerLabel
var nextCheck=0;

func on_message_receive()-> void:
	byteCount= 100;
func set_battery_level(batteryLevel:float):
	batteryLevelLabel.text = "Battery: %f%"% [batteryLevel]
func set_solar_power(solarPowerWatts:float):
	solarPowerLabel.text = "Solar power: %f W"% [solarPowerWatts]
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	nextCheck-=delta;
	if nextCheck<=0:
		nextCheck =1;
		var currentSpeedLimit = byteSpeedLimit+randf_range(-byteSpeedLimit/2,byteSpeedLimit/2)
		netSpeedLabel.text = "TX: %d B/s\nRX: %d B/s" % [min(byteCount,currentSpeedLimit),max(0,min(byteCount,byteSpeedLimit+randf_range(-byteSpeedLimit/2,byteSpeedLimit/2)))]
		if(byteCount>0):
			byteCount=max(0,byteCount- currentSpeedLimit);
		
	pass
