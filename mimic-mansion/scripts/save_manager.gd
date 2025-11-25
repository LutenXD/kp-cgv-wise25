extends Node

const SAVE_PATH = "user://savegame.save"

func save_game(save_data: Dictionary):
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file:
		var json_string = JSON.stringify(save_data)
		save_file.store_line(json_string)
		save_file.close()
		print("Game saved successfully")
		return true
	else:
		print("Failed to save game")
		return false

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found")
		return {}
	
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file:
		var json_string = save_file.get_line()
		save_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			print("Game loaded successfully")
			return json.data
		else:
			print("Failed to parse save file")
			return {}
	else:
		print("Failed to open save file")
		return {}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted")
