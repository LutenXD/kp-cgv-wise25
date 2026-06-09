@tool
extends EditorScript

const ROOM_FOLDER := "res://assets/rooms/"
const OUTPUT_JSON_PATH := "res://data/room_assets.json"
const ROTATIONS := [90, 180, 270]
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

	var all_rooms: Array = []

	for file in room_files:
		var scene_path := ROOM_FOLDER + file
		var room_name := file.get_basename()

		var base_room := extract_room_data(scene_path, room_name)
		if base_room.is_empty():
			push_error("Skipping invalid room: " + scene_path)
			continue

		all_rooms.append(base_room)

		for rot in ROTATIONS:
			all_rooms.append(create_rotated_room_data(base_room, rot))

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
		"name": room_name,
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


func get_door_index(door: Node3D, direction: String) -> int:
	var x := int(round(door.position.x / ROOM_SIZE))
	var z := int(round(door.position.z / ROOM_SIZE))

	match direction:
		"north", "south":
			return x
		"east", "west":
			return z

	return 0


func create_rotated_room_data(room: Dictionary, rotation: int) -> Dictionary:
	var rotated := room.duplicate(true)

	rotated["name"] = String(room["name"]) + "_rot" + str(rotation)
	rotated["rotation"] = rotation

	var width := int(room["width"])
	var length := int(room["length"])

	if rotation == 90 or rotation == 270:
		rotated["width"] = length
		rotated["length"] = width

	rotated["occupied_tiles"] = rotate_tiles(room["occupied_tiles"], width, length, rotation)
	rotated["doors"] = rotate_doors(room["doors"], width, length, rotation)

	return rotated


func rotate_tiles(tiles: Array, width: int, length: int, rotation: int) -> Array:
	var out: Array = []

	for t in tiles:
		var x := int(t[0])
		var z := int(t[1])
		var p := rotate_point(x, z, width, length, rotation)
		out.append([p[0], p[1]])

	return out


func rotate_point(x: int, z: int, width: int, length: int, rotation: int) -> Array:
	match rotation:
		90:
			return [length - 1 - z, x]
		180:
			return [width - 1 - x, length - 1 - z]
		270:
			return [z, width - 1 - x]

	return [x, z]


func rotate_doors(doors: Dictionary, width: int, length: int, rotation: int) -> Dictionary:
	var out := {
		"north": [],
		"east": [],
		"south": [],
		"west": []
	}

	for dir in doors.keys():
		for idx in doors[dir]:
			var result := rotate_door_entry(String(dir), int(idx), width, length, rotation)
			out[result["direction"]].append(result["index"])

	return out


func rotate_door_entry(direction: String, index: int, width: int, length: int, rotation: int) -> Dictionary:
	match rotation:
		90:
			match direction:
				"north":
					return {"direction": "east", "index": index}
				"east":
					return {"direction": "south", "index": length - 1 - index}
				"south":
					return {"direction": "west", "index": index}
				"west":
					return {"direction": "north", "index": length - 1 - index}

		180:
			match direction:
				"north":
					return {"direction": "south", "index": width - 1 - index}
				"east":
					return {"direction": "west", "index": length - 1 - index}
				"south":
					return {"direction": "north", "index": width - 1 - index}
				"west":
					return {"direction": "east", "index": length - 1 - index}

		270:
			match direction:
				"north":
					return {"direction": "west", "index": width - 1 - index}
				"east":
					return {"direction": "north", "index": index}
				"south":
					return {"direction": "east", "index": width - 1 - index}
				"west":
					return {"direction": "south", "index": index}

	return {"direction": direction, "index": index}
