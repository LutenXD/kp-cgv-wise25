@tool
extends EditorScript

# This script generates rotated variants of room scenes and creates JSON metadata
# Run this from Godot: Tools -> Execute script (or assign a shortcut)

const ROOM_FOLDER = "res://assets/rooms/"
const OUTPUT_FOLDER = "res://assets/rot_rooms/"
const OUTPUT_JSON_PATH = "res://data/rot_room_assets.json"
const ROTATIONS = [90, 180, 270]  # Degrees to rotate
const TILE_SIZE = 10.0  # Each floor tile is 10x10 units

func _run():
	print("=== Generating Rotated Room Variants ===")
	
	# Create output directory if it doesn't exist
	DirAccess.make_dir_absolute(OUTPUT_FOLDER)
	print("Output folder: ", OUTPUT_FOLDER)
	
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
	
	# Process each room and collect data
	var all_room_data = []
	
	for room_file in room_files:
		var room_path = ROOM_FOLDER + room_file
		var room_name = room_file.get_basename()
		
		print("\nProcessing: ", room_name)
		
		# Load the original room scene
		var room_scene = load(room_path) as PackedScene
		if not room_scene:
			push_error("Failed to load: " + room_path)
			continue
		
		# Analyze the original room to get its grid structure
		var room_instance = room_scene.instantiate()
		var room_grid_data = analyze_room_grid(room_instance, room_name)
		room_instance.queue_free()
		
		if room_grid_data.is_empty():
			push_error("Failed to analyze room: " + room_name)
			continue
		
		# Copy original room to output folder
		var original_output = OUTPUT_FOLDER + room_file
		var copy_error = ResourceSaver.save(room_scene, original_output)
		if copy_error == OK:
			print("  ✓ Copied original: ", room_name)
			all_room_data.append(room_grid_data)
		else:
			push_error("  ✗ Failed to copy original: " + original_output)
		
		# Generate rotated variants
		for rotation in ROTATIONS:
			var rotated_scene = create_rotated_variant(room_scene, rotation, room_name)
			if rotated_scene:
				var rotated_name = room_name + "_rot" + str(rotation)
				var output_path = OUTPUT_FOLDER + rotated_name + ".tscn"
				var error = ResourceSaver.save(rotated_scene, output_path)
				if error == OK:
					print("  ✓ Created: ", rotated_name)
					
					# Analyze rotated room for JSON
					var rotated_instance = rotated_scene.instantiate()
					var rotated_grid_data = analyze_room_grid(rotated_instance, rotated_name)
					rotated_instance.queue_free()
					
					if not rotated_grid_data.is_empty():
						all_room_data.append(rotated_grid_data)
				else:
					push_error("  ✗ Failed to save: " + output_path)
	
	# Generate JSON with all room data
	generate_room_assets_json(all_room_data)
	
	print("\n=== Generation Complete ===")
	print("Total room variants: ", all_room_data.size())

func analyze_room_grid(room_instance: Node, room_name: String) -> Dictionary:
	"""Analyze a room instance to determine its grid structure and door positions"""
	
	# Get all floor tiles
	var floors_node = room_instance.get_node_or_null("Floor")
	if not floors_node:
		push_error("Room has no 'Floor' node: " + room_name)
		return {}
	
	var floor_tiles = []
	for child in floors_node.get_children():
		floor_tiles.append(child.position)
	
	if floor_tiles.is_empty():
		push_error("Room has no floor tiles: " + room_name)
		return {}
	
	# Find the bounding box of the floor tiles
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF
	
	for tile_pos in floor_tiles:
		min_x = min(min_x, tile_pos.x)
		max_x = max(max_x, tile_pos.x)
		min_z = min(min_z, tile_pos.z)
		max_z = max(max_z, tile_pos.z)
	
	# Calculate grid dimensions (in number of tiles)
	var width = int(round((max_x - min_x) / TILE_SIZE)) + 1
	var length = int(round((max_z - min_z) / TILE_SIZE)) + 1
	
	# Create a grid representation to track which cells have tiles
	var grid = {}
	for tile_pos in floor_tiles:
		var grid_x = int(round((tile_pos.x - min_x) / TILE_SIZE))
		var grid_z = int(round((tile_pos.z - min_z) / TILE_SIZE))
		grid[Vector2i(grid_x, grid_z)] = true
	
	# Analyze doors
	var door_data = analyze_doors(room_instance, min_x, min_z, width, length, grid)
	
	print("    Grid: ", width, "x", length, " tiles")
	print("    Doors: N:", door_data["north"].size(), " S:", door_data["south"].size(), 
		  " E:", door_data["east"].size(), " W:", door_data["west"].size())
	
	return {
		"name": room_name,
		"width": width,
		"length": length,
		"grid": grid,  # Store grid for collision detection
		"doors": door_data
	}

func analyze_doors(room_instance: Node, min_x: float, min_z: float, width: int, length: int, grid: Dictionary) -> Dictionary:
	"""Analyze door positions in the room"""
	
	var doors = {
		"north": [],
		"south": [],
		"east": [],
		"west": []
	}
	
	var walls_node = room_instance.get_node_or_null("Walls")
	if not walls_node:
		return doors
	
	# Find all door nodes
	for child in walls_node.get_children():
		var node_name = child.name
		var direction = ""
		
		if node_name.begins_with("DoorNorth"):
			direction = "north"
		elif node_name.begins_with("DoorSouth"):
			direction = "south"
		elif node_name.begins_with("DoorEast"):
			direction = "east"
		elif node_name.begins_with("DoorWest"):
			direction = "west"
		
		if direction != "":
			# Calculate door position as grid index
			var door_pos = child.position
			var grid_index = 0
			
			match direction:
				"north", "south":
					# Doors along x-axis
					grid_index = int(round((door_pos.x - min_x) / TILE_SIZE))
				"east", "west":
					# Doors along z-axis
					grid_index = int(round((door_pos.z - min_z) / TILE_SIZE))
			
			doors[direction].append(grid_index)
	
	return doors

func create_rotated_variant(original_scene: PackedScene, rotation_degrees: int, room_name: String) -> PackedScene:
	"""Create a rotated copy of a room scene"""
	
	# Instantiate the original scene
	var room_instance = original_scene.instantiate()
	
	# Rotate the entire room
	room_instance.rotation_degrees.y = rotation_degrees
	
	# Rename walls to match their new orientation after rotation
	rename_walls_for_rotation(room_instance, rotation_degrees)
	
	# Rename doors to match their new orientation after rotation
	rename_doors_for_rotation(room_instance, rotation_degrees)
	
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
			direction_map = {"North": "West", "East": "North", "South": "East", "West": "South"}
		180:
			direction_map = {"North": "South", "East": "West", "South": "North", "West": "East"}
		270:
			direction_map = {"North": "East", "East": "South", "South": "West", "West": "North"}
	
	if direction_map.is_empty():
		return
	
	# Step 1: Rename all walls to temporary names
	var walls_to_process = []
	for child in walls_node.get_children():
		var wall_name = child.name
		for old_dir in direction_map.keys():
			if wall_name.begins_with("Wall" + old_dir):
				var new_dir = direction_map[old_dir]
				var suffix = wall_name.substr(4 + old_dir.length())
				var temp_name = "TEMP_Wall" + new_dir + suffix
				var final_name = "Wall" + new_dir + suffix
				walls_to_process.append({"node": child, "temp_name": temp_name, "final_name": final_name})
				child.name = temp_name
				break
	
	# Step 2: Remove the TEMP_ prefix
	for item in walls_to_process:
		item["node"].name = item["final_name"]

func rename_doors_for_rotation(room_instance: Node, rotation: int):
	"""Rename doors to match their new orientation after rotation"""
	var doors_node = room_instance.get_node_or_null("Walls")
	if not doors_node:
		return
	
	# Determine direction mapping based on rotation
	var direction_map = {}
	match rotation:
		90:
			direction_map = {"North": "West", "East": "North", "South": "East", "West": "South"}
		180:
			direction_map = {"North": "South", "East": "West", "South": "North", "West": "East"}
		270:
			direction_map = {"North": "East", "East": "South", "South": "West", "West": "North"}
	
	if direction_map.is_empty():
		return
	
	# Step 1: Rename all doors to temporary names
	var doors_to_process = []
	for child in doors_node.get_children():
		var door_name = child.name
		for old_dir in direction_map.keys():
			if door_name.begins_with("Door" + old_dir):
				var new_dir = direction_map[old_dir]
				var suffix = door_name.substr(4 + old_dir.length())
				var temp_name = "TEMP_Door" + new_dir + suffix
				var final_name = "Door" + new_dir + suffix
				doors_to_process.append({"node": child, "temp_name": temp_name, "final_name": final_name})
				child.name = temp_name
				break
	
	# Step 2: Remove the TEMP_ prefix
	for item in doors_to_process:
		item["node"].name = item["final_name"]

func generate_room_assets_json(room_data_array: Array):
	"""Generate a JSON file with all room data"""
	print("\n=== Generating Room Assets JSON ===")
	
	# Convert room data to JSON-friendly format
	var json_rooms = []
	for room_data in room_data_array:
		# Convert grid dictionary to array of occupied cells
		var occupied_cells = []
		for cell in room_data["grid"].keys():
			occupied_cells.append({"x": cell.x, "z": cell.y})
		
		json_rooms.append({
			"name": room_data["name"],
			"width": room_data["width"],
			"length": room_data["length"],
			"occupied_cells": occupied_cells,
			"doors": room_data["doors"]
		})
	
	# Create output JSON
	var output_data = {"rooms": json_rooms}
	var output_json = JSON.stringify(output_data, "  ")
	
	# Save to file
	var output_file = FileAccess.open(OUTPUT_JSON_PATH, FileAccess.WRITE)
	if not output_file:
		push_error("Failed to create: " + OUTPUT_JSON_PATH)
		return
	
	output_file.store_string(output_json)
	output_file.close()
	
	print("✓ Generated room assets JSON: ", OUTPUT_JSON_PATH)
	print("  Total room variants: ", json_rooms.size())
