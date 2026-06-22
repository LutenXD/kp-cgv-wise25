@tool
extends EditorScript

const ROOM_FOLDER := "res://assets/rot_rooms/"
const OUTPUT_JSON_PATH := "res://data/room_assets.json"
const ROOM_SIZE := 10.0


func _run() -> void:
	print("=== Generating Room Assets JSON From Scenes ===")

	var room_files: Array[String] = []
	var dir := DirAccess.open(ROOM_FOLDER)
	if dir == null:
		push_error("Failed to open room folder: " + ROOM_FOLDER)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			room_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if room_files.is_empty():
		push_error("No .tscn files found in " + ROOM_FOLDER)
		return

	var all_rooms: Dictionary = {}  # Changed: Array -> Dictionary

	for file in room_files:
		var scene_path := ROOM_FOLDER + file
		var room_name := file.get_basename()

		var base_room := extract_room_data(scene_path, room_name)
		if base_room.is_empty():
			push_error("Skipping invalid room: " + scene_path)
			continue

		all_rooms[room_name] = base_room  # Changed: append() -> keyed insert

	var output_data := {"rooms": all_rooms}
	var output_json := JSON.stringify(output_data, "  ")

	var out_file := FileAccess.open(OUTPUT_JSON_PATH, FileAccess.WRITE)
	if out_file == null:
		push_error("Failed to write: " + OUTPUT_JSON_PATH)
		return

	out_file.store_string(output_json)
	out_file.close()

	print("✓ Wrote: ", OUTPUT_JSON_PATH)
	print("✓ Rooms: ", all_rooms.size())


func extract_room_data(scene_path: String, room_name: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Failed to load: " + scene_path)
		return {}

	var room := packed.instantiate()
	if room == null:
		push_error("Failed to instantiate: " + scene_path)
		return {}

	var floor_node := room.get_node_or_null("Floor")
	var walls_node := room.get_node_or_null("Walls")

	if floor_node == null or walls_node == null:
		room.free()
		push_error("Room missing Floor or Walls node: " + scene_path)
		return {}

	var occupied := collect_occupied_tiles(floor_node)
	if occupied.is_empty():
		room.free()
		push_error("No floor tiles found in: " + scene_path)
		return {}

	var bounds := get_tile_bounds(occupied)
	var normalized_tiles := normalize_tiles(occupied, bounds["min_x"], bounds["min_z"])

	var doors := collect_doors(walls_node)

	room.free()

	return {
		# "name" removed — it's now the dictionary key one level up
		"scene": scene_path,
		"rotation": 0,
		"width": bounds["width"],
		"length": bounds["length"],
		"occupied_tiles": normalized_tiles,
		"doors": doors
	}


func collect_occupied_tiles(floor_node: Node) -> Array:
	var tiles: Array = []

	for child in floor_node.get_children():
		if child is Node3D:
			var x := int(round(child.position.x / ROOM_SIZE))
			var z := int(round(child.position.z / ROOM_SIZE))
			tiles.append([x, z])

	return tiles


func get_tile_bounds(tiles: Array) -> Dictionary:
	var min_x := 999999
	var min_z := 999999
	var max_x := -999999
	var max_z := -999999

	for t in tiles:
		var x := int(t[0])
		var z := int(t[1])

		if x < min_x:
			min_x = x
		if z < min_z:
			min_z = z
		if x > max_x:
			max_x = x
		if z > max_z:
			max_z = z

	return {
		"min_x": min_x,
		"min_z": min_z,
		"width": max_x - min_x + 1,
		"length": max_z - min_z + 1
	}


func normalize_tiles(tiles: Array, min_x: int, min_z: int) -> Array:
	var out: Array = []
	for t in tiles:
		out.append([int(t[0]) - min_x, int(t[1]) - min_z])
	return out


func collect_doors(walls_node: Node) -> Dictionary:
	var doors := {
		"north": [],
		"east": [],
		"south": [],
		"west": []
	}

	for child in walls_node.get_children():
		if not (child is Node3D):
			continue

		var name := String(child.name)
		var direction := get_door_direction_from_name(name)
		if direction == "":
			continue

		var index := get_door_index(child as Node3D, direction)
		doors[direction].append(index)

	return doors


func get_door_direction_from_name(name: String) -> String:
	if name.begins_with("DoorNorth"):
		return "north"
	if name.begins_with("DoorEast"):
		return "east"
	if name.begins_with("DoorSouth"):
		return "south"
	if name.begins_with("DoorWest"):
		return "west"
	return ""


func get_door_index(door: Node3D, _direction: String) -> int:
	return door.name.right(1) as int
