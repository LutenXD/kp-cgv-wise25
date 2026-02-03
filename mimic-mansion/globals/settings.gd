extends Node


signal update


var mouse_sensitivity: float = 50.0:
	set(v):
		mouse_sensitivity = v * 0.00002
		update.emit()

var volume_master: float = 50.0:
	set(v):
		volume_master = v
		AudioServer.set_bus_volume_db(0, linear_to_db(volume_master * 0.02))
		AudioServer.set_bus_mute(0, volume_master * 0.1 < 0.01)

var volume_music: float = 50.0:
	set(v):
		volume_music = v
		AudioServer.set_bus_volume_db(4, linear_to_db(volume_music * 0.02))
		AudioServer.set_bus_mute(3, volume_music * 0.1 < 0.01)

var volume_sound: float = 50.0:
	set(v):
		volume_sound = v
		AudioServer.set_bus_volume_db(3, linear_to_db(volume_sound * 0.02))
		AudioServer.set_bus_mute(3, volume_sound * 0.1 < 0.01)
		AudioServer.set_bus_volume_db(5, linear_to_db(volume_sound * 0.04))
		AudioServer.set_bus_mute(5, volume_sound * 0.1 < 0.01)

var volume_tts: float = 50.0:
	set(v):
		volume_tts = v
		AudioServer.set_bus_volume_db(2, linear_to_db(volume_tts * 0.04))
		AudioServer.set_bus_mute(2, volume_tts * 0.1 < 0.01)
