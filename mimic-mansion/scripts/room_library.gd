extends RefCounted # Use RefCounted for data helper classes
class_name RoomLibrary

var room_data = {} 

func load_manifest(path: String):
	if not FileAccess.file_exists(path):
		push_error("Room manifest missing at: " + path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		var data = json.data
		if data.has("rooms"):
			for room in data["rooms"]:
				room_data[room["name"]] = room
			print("Loaded ", room_data.size(), " room definitions.")
	else:
		push_error("JSON Parse Error: ", json.get_error_message())

func get_random_room_with_door(needed_dir: String, exclude_list: Array) -> Dictionary:
	var candidates = []
	for r_name in room_data:
		# Check if it has the door
		if room_data[r_name]["doors"][needed_dir].size() > 0:
			# Check if we already spawned the base version of this room
			var base_name = r_name.split("_rot")[0]
			if not exclude_list.has(base_name):
				candidates.append(room_data[r_name])
	
	if candidates.is_empty():
		return {}
	return candidates.pick_random()
