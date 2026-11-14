extends Node
## Game-wide audio, autoloaded as Audio. Transmissions share one voice channel, so a new one cuts off the old.

var _voice := AudioStreamPlayer.new()


func _ready() -> void:
	add_child(_voice)


func play_voice(stream: AudioStream) -> void:
	_voice.stream = stream
	_voice.play()


func stop_voice() -> void:
	_voice.stop()
