extends Node3D
class_name RoomLayoutManager

# Configuration
const STARTING_ROOM_PATH = "res://assets/rooms/grand_foyer.tscn"
const STARTING_ROOM_POSITION = Vector3.ZERO
const ROOM_ASSETS_PATH = "res://data/room_assets.json"

# Room tracking
var spawned_rooms: Array[Dictionary] = [] # Track spawned rooms with their position and type
var room_data: Dictionary = {} # Room definitions from JSON

func _ready():
	name = "RoomLayoutManager"
	load_room_data()

func load_room_data():
	"""Load and parse room_assets.json"""
	var file = FileAccess.open(ROOM_ASSETS_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open room_assets.json at: " + ROOM_ASSETS_PATH)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Failed to parse room_assets.json: " + json.get_error_message())
		return
	
	var data = json.data
	if not data.has("rooms"):
		push_error("room_assets.json missing 'rooms' array")
		return
	
	# Convert array to dictionary for easier lookup
	for room in data["rooms"]:
		var room_name = room["name"]
		room_data[room_name] = room
		
		# Create rotated versions of each room
		for rotation in [90, 180, 270]:
			var rotated_room = room.duplicate(true)
			var rotated_name = room_name + "_rot" + str(rotation)
			
			# Rotate door positions based on rotation angle
			var rotated_doors = {"north": [], "east": [], "south": [], "west": []}
			
			match rotation:
				90:
					# 90° clockwise: north->east, east->south, south->west, west->north
					rotated_doors["east"] = room["doors"]["north"].duplicate()
					rotated_doors["south"] = room["doors"]["east"].duplicate()
					rotated_doors["west"] = room["doors"]["south"].duplicate()
					rotated_doors["north"] = room["doors"]["west"].duplicate()
				180:
					# 180°: north->south, east->west, south->north, west->east
					rotated_doors["south"] = room["doors"]["north"].duplicate()
					rotated_doors["west"] = room["doors"]["east"].duplicate()
					rotated_doors["north"] = room["doors"]["south"].duplicate()
					rotated_doors["east"] = room["doors"]["west"].duplicate()
				270:
					# 270° clockwise (90° counter-clockwise): north->west, east->north, south->east, west->south
					rotated_doors["west"] = room["doors"]["north"].duplicate()
					rotated_doors["north"] = room["doors"]["east"].duplicate()
					rotated_doors["east"] = room["doors"]["south"].duplicate()
					rotated_doors["south"] = room["doors"]["west"].duplicate()
			
			rotated_room["name"] = rotated_name
			rotated_room["doors"] = rotated_doors
			rotated_room["rotation"] = rotation
			rotated_room["original_name"] = room_name
			room_data[rotated_name] = rotated_room
	
	print("Loaded ", room_data.size(), " room definitions (including rotated versions)")

func get_room_doors(room_name: String) -> Dictionary:
	"""Get door configuration for a room"""
	if not room_data.has(room_name):
		push_error("Room not found in room_data: " + room_name)
		return {"north": [], "east": [], "south": [], "west": []}
	
	return room_data[room_name].get("doors", {"north": [], "east": [], "south": [], "west": []})

func get_room_dimensions(room_name: String) -> Vector2:
	"""Get room dimensions (width, length) from room data"""
	if not room_data.has(room_name):
		push_error("Room not found in room_data: " + room_name)
		return Vector2(1, 1) # Default to 1x1
	
	var data = room_data[room_name]
	return Vector2(data.get("width", 1), data.get("length", 1))

func spawn_room(room_scene_path: String = "res://assets/rooms/grand_foyer.tscn", position: Vector3 = Vector3.ZERO, rotation_degrees: float = 0.0):
	"""Spawn a single room in the scene"""
	
	# Check if this is a rotated variant that doesn't have a scene file
	var room_name = room_scene_path.get_file().get_basename()
	var base_scene_path = room_scene_path
	var actual_rotation = rotation_degrees
	
	# If requesting a rotated variant that doesn't exist, use base room with rotation
	if "_rot" in room_name and not ResourceLoader.exists(room_scene_path):
		# Extract base room name and rotation
		var parts = room_name.split("_rot")
		if parts.size() == 2:
			var base_name = parts[0]
			var rot_angle = parts[1].to_int()
			base_scene_path = "res://assets/rooms/" + base_name + ".tscn"
			actual_rotation = rot_angle
			print("  Generating rotated variant: ", base_name, " with ", rot_angle, "° rotation")
	
	var room_scene = ResourceLoader.load(base_scene_path, "", ResourceLoader.CACHE_MODE_REUSE)
	
	if not room_scene:
		var error = ResourceLoader.load_threaded_get_status(base_scene_path)
		push_error("Failed to load room scene: " + base_scene_path + " Error: " + str(error))
		return null

	var room_instance = room_scene.instantiate()
	
	if not room_instance:
		push_error("Failed to instantiate room")
		return null
	
	room_instance.name = "Room_" + room_name
	
	add_child(room_instance)
	
	room_instance.global_position = position
	room_instance.rotation_degrees.y = actual_rotation
	
	# Rename walls to match rotation if room is rotated
	if actual_rotation != 0.0:
		rename_walls_for_rotation(room_instance, actual_rotation)
	
	return room_instance

func rename_walls_for_rotation(room_instance: Node3D, rotation: float):
	"""Rename walls to match their new orientation after rotation"""
	var walls_node = room_instance.get_node_or_null("Walls")
	if not walls_node:
		return
	
	# Determine direction mapping based on rotation
	var direction_map = {}
	match int(rotation):
		90:
			# 90° clockwise: north->east, east->south, south->west, west->north
			direction_map = {"North": "East", "East": "South", "South": "West", "West": "North"}
		180:
			# 180°: north->south, east->west, south->north, west->east
			direction_map = {"North": "South", "East": "West", "South": "North", "West": "East"}
		270:
			# 270° clockwise: north->west, east->north, south->east, west->south
			direction_map = {"North": "West", "East": "North", "South": "East", "West": "South"}
	
	if direction_map.is_empty():
		return
	
	# Collect all walls to rename (to avoid modifying while iterating)
	var walls_to_rename = []
	for child in walls_node.get_children():
		var wall_name = child.name
		for old_dir in direction_map.keys():
			if wall_name.begins_with("Wall" + old_dir):
				var new_dir = direction_map[old_dir]
				var suffix = wall_name.substr(4 + old_dir.length()) # Get the number part
				var new_name = "Wall" + new_dir + suffix
				walls_to_rename.append({"node": child, "new_name": new_name})
				break
	
	# Apply the renames
	for item in walls_to_rename:
		item["node"].name = item["new_name"]
	
	print("  Renamed ", walls_to_rename.size(), " walls for ", rotation, "° rotation")

func spawn_starting_room():
	"""Spawn the starting room at the configured position"""
	print("RoomLayoutManager: Spawning starting room...")
	var room = spawn_room(STARTING_ROOM_PATH, STARTING_ROOM_POSITION)
	if room:
		print("✓ Starting room spawned successfully")
		
		# Get the room name from the path
		var room_name = STARTING_ROOM_PATH.get_file().get_basename()
		
		# Read and display door configuration
		var doors = get_room_doors(room_name)
		print("Room: ", room_name)
		print("  Doors - North: ", doors["north"], " East: ", doors["east"], " South: ", doors["south"], " West: ", doors["west"])
		
		# Get dimensions
		var dimensions = get_room_dimensions(room_name)
		print("  Dimensions - Width: ", dimensions.x, " Length: ", dimensions.y)
		
		spawned_rooms.append({
			"name": room_name,
			"position": STARTING_ROOM_POSITION,
			"rotation_degrees": 0.0,
			"scene_path": STARTING_ROOM_PATH,
			"unused_doors": doors
		})
		
		spawn_additional_room()

		return room
	else:
		push_error("Failed to spawn starting room!")
		return null

func restore_room_layout(saved_rooms: Array):
	"""Restore previously spawned rooms from saved data"""
	print("RoomLayoutManager: Restoring ", saved_rooms.size(), " saved rooms...")
	
	spawned_rooms.clear()
	
	for room_data_dict in saved_rooms:
		var room_name = room_data_dict.get("name", "")
		var position = room_data_dict.get("position", Vector3.ZERO)
		var rotation = room_data_dict.get("rotation_degrees", 0.0)
		var scene_path = room_data_dict.get("scene_path", "")
		
		# Spawn the room at saved position and rotation
		var room = spawn_room(scene_path, position, rotation)
		
		if room:
			# Add to spawned rooms array with saved data
			spawned_rooms.append(room_data_dict.duplicate())
			print("✓ Restored room: ", room_name, " at ", position)
		else:
			push_error("Failed to restore room: " + room_name)
	
	print("✓ Room layout restored successfully")

func spawn_additional_room():
	"""Spawn an additional room connected to an available door"""
	var available_doors = get_available_doors() 
	
	if available_doors.size() == 0:
		print("No available doors to spawn additional rooms.")
		return null
	
	var door_info = available_doors[randi() % available_doors.size()]
	var door_direction = door_info["door_direction"]
	var parent_position = door_info["position"]
	var parent_rotation = door_info["rotation_degrees"]
	var parent_room_name = door_info["room_name"]
	
	print("Spawning additional room at door: ", door_info)

	# Get list of available room types that haven't been spawned yet
	var spawned_room_names = []
	for room in spawned_rooms:
		spawned_room_names.append(room["name"])

	var available_room_types = []
	for room_name in room_data.keys():
		if not spawned_room_names.has(room_name):
			available_room_types.append(room_name)

	if available_room_types.size() == 0:
		print("No new room types available to spawn.")
		return null

	# Select a random room type
	var selected_room_name = available_room_types[randi() % available_room_types.size()]
	print("Selected room type: ", selected_room_name)

	# Get dimensions of both rooms
	var parent_dimensions = get_room_dimensions(parent_room_name)
	var new_dimensions = get_room_dimensions(selected_room_name)
	var grid_size = 10.0  # Each room unit is 10x10 in world space
	
	# Calculate offset based on door direction and room dimensions
	# Position the new room so its edge aligns with the parent's edge
	var offset = Vector3.ZERO
	match door_direction:
		"north":
			# New room connects to parent's north side, extends northward (-Z)
			# Offset by half of parent's length + half of new room's length
			offset = Vector3(0, 0, -(parent_dimensions.y * grid_size * 0.5 + new_dimensions.y * grid_size * 0.5))
		"east":
			# New room connects to parent's east side, extends eastward (+X)
			# Offset by half of parent's width + half of new room's width
			offset = Vector3(parent_dimensions.x * grid_size * 0.5 + new_dimensions.x * grid_size * 0.5, 0, 0)
		"south":
			# New room connects to parent's south side, extends southward (+Z)
			# Offset by half of parent's length + half of new room's length
			offset = Vector3(0, 0, parent_dimensions.y * grid_size * 0.5 + new_dimensions.y * grid_size * 0.5)
		"west":
			# New room connects to parent's west side, extends westward (-X)
			# Offset by half of parent's width + half of new room's width
			offset = Vector3(-(parent_dimensions.x * grid_size * 0.5 + new_dimensions.x * grid_size * 0.5), 0, 0)
	
	# Apply parent rotation to the offset
	var rotated_offset = offset.rotated(Vector3.UP, deg_to_rad(parent_rotation))
	var new_room_position = parent_position + rotated_offset
	
	print("  Parent: ", parent_room_name, " (", parent_dimensions.x, "x", parent_dimensions.y, ") at ", parent_position)
	print("  New: ", selected_room_name, " (", new_dimensions.x, "x", new_dimensions.y, ") at ", new_room_position)
	print("  Door direction: ", door_direction)
	
	# Determine the base room name (without rotation suffix)
	var base_room_name = selected_room_name
	var rotation_for_spawn = 0.0
	
	if "_rot" in selected_room_name:
		base_room_name = room_data[selected_room_name].get("original_name", base_room_name)
		rotation_for_spawn = room_data[selected_room_name].get("rotation", 0.0)
	
	# Use the selected room name (with rotation suffix) as the scene path
	# The spawn_room function will handle loading base room + applying rotation
	var room_scene_path = "res://assets/rooms/" + selected_room_name + ".tscn"
	var new_room = spawn_room(room_scene_path, new_room_position, rotation_for_spawn)
	
	if new_room:
		# Disable connecting walls
		var opposing_dirs = {
			"north": "south", "south": "north", 
			"east": "west", "west": "east"
		}
		
		# 1. Disable parent room's wall at the connecting door
		var parent_room_node = get_node_or_null("Room_" + parent_room_name)
		if parent_room_node:
			var parent_walls_node = parent_room_node.get_node_or_null("Walls")
			if parent_walls_node:
				var parent_door_index = int(door_info["door_info"])
				var parent_wall_name = "Wall" + door_direction.capitalize() + str(parent_door_index)
				var parent_wall = parent_walls_node.get_node_or_null(parent_wall_name)
				if parent_wall:
					parent_wall.queue_free()
					print("  Disabled parent wall: ", parent_wall_name)
		
		# 2. Disable new room's wall at the connecting door (regardless of door existence)
		var new_walls_node = new_room.get_node_or_null("Walls")
		if new_walls_node:
			var opposing_door_direction = opposing_dirs[door_direction]
			
			# Disable the wall at the connecting door (always try index 0)
			var connecting_wall_name = "Wall" + opposing_door_direction.capitalize() + "0"
			var connecting_wall = new_walls_node.get_node_or_null(connecting_wall_name)
			if connecting_wall:
				connecting_wall.queue_free()
				print("  Disabled new room connecting wall: ", connecting_wall_name)
		
		# Track the new room
		var doors = get_room_doors(selected_room_name)
		spawned_rooms.append({
			"name": selected_room_name,
			"position": new_room_position,
			"rotation_degrees": rotation_for_spawn,
			"scene_path": room_scene_path,
			"unused_doors": doors
		})
		
		print("Spawned room: ", selected_room_name)
		return new_room
	else:
		push_error("Failed to spawn room: " + selected_room_name)
		return null
	



func get_available_doors():
	"""Get a list of all available doors in spawned rooms"""
	var available_doors = []
	
	for room_info in spawned_rooms:
		var unused_doors = room_info["unused_doors"]
		
		for direction in unused_doors.keys():
			for door in unused_doors[direction]:
				available_doors.append({
					"room_name": room_info["name"],
					"position": room_info["position"],
					"rotation_degrees": room_info["rotation_degrees"],
					"door_direction": direction,
					"door_info": door
				})
	
	return available_doors
	
