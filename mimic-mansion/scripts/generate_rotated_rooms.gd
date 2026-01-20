@tool
extends EditorScript

# This script generates rotated variants of room scenes
# Run this from Godot: File -> Run

const ROOM_FOLDER = "res://assets/rooms/"
const OUTPUT_FOLDER = "res://assets/game_rooms/"
const ROTATIONS = [90, 180, 270]  # Degrees to rotate

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
