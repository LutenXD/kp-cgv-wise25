@tool
extends EditorScript

# This script generates rotated variants of room scenes
# Run this from Godot: File -> Run

const ROOM_FOLDER = "res://assets/rooms/"
const OUTPUT_FOLDER = "res://assets/rot_rooms/"
const ROOM_ASSETS_PATH = "res://data/room_assets.json"
const OUTPUT_JSON_PATH = "res://data/rot_room_assets.json"
const ROTATIONS = [90, 180, 270]  # Degrees to rotate

func _run():
	print("=== Generating Rotated Room Variants ===")
	
	# Create output directory if it doesn't exist
	DirAccess.make_dir_absolute(OUTPUT_FOLDER)
	print("Output folder: ", OUTPUT_FOLDER)
	
	# Generate rotated room assets JSON
	generate_rotated_room_assets_json()
	
	# Read all .tscn files from the rooms folder
	var room_files = []
	var dir = DirAccess.open(ROOM_FOLDER)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tscn"):
				room_files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		print("Found ", room_files.size(), " room files")
	else:
		push_error("Failed to open directory: " + ROOM_FOLDER)
		return
	
	if room_files.is_empty():
		push_error("No .tscn files found in " + ROOM_FOLDER)
		return
	
	for room_file in room_files:
		var room_path = ROOM_FOLDER + room_file
		var room_name = room_file.get_basename()
		
		print("\nProcessing: ", room_name)
		
		# Load the original room scene
		var room_scene = load(room_path) as PackedScene
		if not room_scene:
			push_error("Failed to load: " + room_path)
			continue
		
		# Copy original room to game_rooms folder
		var original_output = OUTPUT_FOLDER + room_file
		var copy_error = ResourceSaver.save(room_scene, original_output)
		if copy_error == OK:
			print("  ✓ Copied original: ", room_name)
		else:
			push_error("  ✗ Failed to copy original: " + original_output)
		
		# Generate rotated variants
		for rotation in ROTATIONS:
			var rotated_scene = create_rotated_variant(room_scene, rotation)
			if rotated_scene:
				var output_path = OUTPUT_FOLDER + room_name + "_rot" + str(rotation) + ".tscn"
				var error = ResourceSaver.save(rotated_scene, output_path)
				if error == OK:
					print("  ✓ Created: ", room_name, "_rot", rotation)
				else:
					push_error("  ✗ Failed to save: " + output_path + " Error: " + str(error))
	
	print("\n=== Generation Complete ===")
	print("Total files created: ", (room_files.size() * 4), " (", room_files.size(), " originals + ", room_files.size() * 3, " rotated variants)")

func create_rotated_variant(original_scene: PackedScene, rotation_degrees: int) -> PackedScene:
	"""Create a rotated copy of a room scene"""
	# Instantiate the original scene
	var room_instance = original_scene.instantiate()
	
	# Rotate the entire room
	room_instance.rotation_degrees.y = rotation_degrees
	
	# Rename walls to match their new orientation after rotation
	rename_walls_for_rotation(room_instance, rotation_degrees)
	
	# Create a new packed scene from the rotated instance
	var rotated_scene = PackedScene.new()
	rotated_scene.pack(room_instance)
	
	# Clean up the instance
	room_instance.queue_free()
	
	return rotated_scene

func rename_walls_for_rotation(room_instance: Node, rotation: int):
	"""Rename walls to match their new orientation after rotation"""
	var walls_node = room_instance.get_node_or_null("Walls")
	if not walls_node:
		return
	
	# Determine direction mapping based on rotation
	var direction_map = {}
	match rotation:
		90:
			# 90° clockwise rotation: north wall moves to west, east to north, south to east, west to south
			direction_map = {"North": "West", "East": "North", "South": "East", "West": "South"}
		180:
			# 180°: north->south, east->west, south->north, west->east
			direction_map = {"North": "South", "East": "West", "South": "North", "West": "East"}
		270:
			# 270° clockwise (90° counter-clockwise): north->east, east->south, south->west, west->north
			direction_map = {"North": "East", "East": "South", "South": "West", "West": "North"}
	
	if direction_map.is_empty():
		return
	
	# Step 1: Rename all walls to temporary names to avoid conflicts
	var walls_to_process = []
	for child in walls_node.get_children():
		var wall_name = child.name
		for old_dir in direction_map.keys():
			if wall_name.begins_with("Wall" + old_dir):
				var new_dir = direction_map[old_dir]
				var suffix = wall_name.substr(4 + old_dir.length()) # Get the number part
				var temp_name = "TEMP_Wall" + new_dir + suffix
				var final_name = "Wall" + new_dir + suffix
				walls_to_process.append({"node": child, "temp_name": temp_name, "final_name": final_name})
				child.name = temp_name
				break
	
	# Step 2: Remove the TEMP_ prefix from all walls
	for item in walls_to_process:
		item["node"].name = item["final_name"]
	
	if walls_to_process.size() > 0:
		print("    → Renamed ", walls_to_process.size(), " walls for ", rotation, "° rotation")

func generate_rotated_room_assets_json():
	"""Generate a JSON file with all room variants including rotations"""
	print("\n=== Generating Rotated Room Assets JSON ===")
	
	# Load the original room assets
	var file = FileAccess.open(ROOM_ASSETS_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open: " + ROOM_ASSETS_PATH)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("Failed to parse JSON: " + ROOM_ASSETS_PATH)
		return
	
	var room_data = json.get_data()
	if not room_data.has("rooms"):
		push_error("Invalid room_assets.json format")
		return
	
	# Create rotated variants
	var all_rooms = []
	for room in room_data["rooms"]:
		# Add original room
		var original_room = room.duplicate(true)
		all_rooms.append(original_room)
		
		# Add rotated variants
		for rotation in ROTATIONS:
			var rotated_room = create_rotated_room_data(room, rotation)
			all_rooms.append(rotated_room)
	
	# Create output JSON
	var output_data = {"rooms": all_rooms}
	var output_json = JSON.stringify(output_data, "  ")
	
	# Save to file
	var output_file = FileAccess.open(OUTPUT_JSON_PATH, FileAccess.WRITE)
	if not output_file:
		push_error("Failed to create: " + OUTPUT_JSON_PATH)
		return
	
	output_file.store_string(output_json)
	output_file.close()
	
	print("✓ Generated rotated room assets JSON: ", OUTPUT_JSON_PATH)
	print("  Total room variants: ", all_rooms.size(), " (", room_data["rooms"].size(), " originals + ", room_data["rooms"].size() * 3, " rotated)")

func create_rotated_room_data(room: Dictionary, rotation_degrees: int) -> Dictionary:
	"""Create a rotated version of room data with rotated door positions"""
	var rotated_room = room.duplicate(true)
	
	# Update name with rotation suffix
	rotated_room["name"] = room["name"] + "_rot" + str(rotation_degrees)
	
	# For rectangular rooms, swap width and length for 90/270 degree rotations
	if rotation_degrees == 90 or rotation_degrees == 270:
		var temp = rotated_room["width"]
		rotated_room["width"] = rotated_room["length"]
		rotated_room["length"] = temp
	
	# Rotate door positions
	var original_doors = room["doors"]
	var rotated_doors = rotate_doors(original_doors, rotation_degrees, room["width"], room["length"])
	rotated_room["doors"] = rotated_doors
	
	return rotated_room

func rotate_doors(doors: Dictionary, rotation: int, width: int, length: int) -> Dictionary:
	"""Rotate door positions based on rotation angle"""
	var rotated_doors = {
		"north": [],
		"east": [],
		"south": [],
		"west": []
	}
	
	# Determine direction mapping based on rotation
	var direction_map = {}
	match rotation:
		90:
			# 90° clockwise: north->west, east->north, south->east, west->south
			direction_map = {"north": "west", "east": "north", "south": "east", "west": "south"}
		180:
			# 180°: north->south, east->west, south->north, west->east
			direction_map = {"north": "south", "east": "west", "south": "north", "west": "east"}
		270:
			# 270° clockwise: north->east, east->south, south->west, west->north
			direction_map = {"north": "east", "east": "south", "south": "west", "west": "north"}
	
	# Rotate each door to its new direction
	for direction in doors.keys():
		var new_direction = direction_map[direction]
		var door_positions = doors[direction]
		
		# Transform door positions based on rotation
		var new_positions = []
		for pos in door_positions:
			var new_pos = transform_door_position(pos, direction, rotation, width, length)
			new_positions.append(new_pos)
		
		rotated_doors[new_direction] = new_positions
	
	return rotated_doors

func transform_door_position(pos: int, original_direction: String, rotation: int, width: int, length: int) -> int:
	"""Transform a door position index based on rotation"""
	# For 90/270 rotations, positions may need to be transformed
	# based on the change in room dimensions
	match rotation:
		90:
			# When rotating 90° clockwise:
			# - north wall (width) -> west wall (length): pos needs adjustment
			# - east wall (length) -> north wall (width): reverse position
			# - south wall (width) -> east wall (length): pos needs adjustment
			# - west wall (length) -> south wall (width): reverse position
			match original_direction:
				"north", "south":  # Width -> Length
					return pos
				"east", "west":  # Length -> Width
					return (length - 1) - pos if length > 1 else pos
		180:
			# 180° rotation reverses positions along the same dimension
			match original_direction:
				"north", "south":
					return (width - 1) - pos if width > 1 else pos
				"east", "west":
					return (length - 1) - pos if length > 1 else pos
		270:
			# 270° clockwise (90° counter-clockwise)
			match original_direction:
				"north", "south":  # Width -> Length
					return (width - 1) - pos if width > 1 else pos
				"east", "west":  # Length -> Width
					return pos
	
	return pos
