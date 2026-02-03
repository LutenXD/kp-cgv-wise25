extends Node3D
class_name RoomLayoutManager2

signal finished

# Path to the rotated rooms folder and JSON data
const ROT_ROOMS_PATH = "res://assets/rot_rooms/"
const ROT_ROOM_ASSETS_JSON = "res://data/rot_room_assets.json"

# Grid settings for room placement
const ROOM_SIZE = 10.0  # Base size of a room (10x10 units)
var grid = {}  # Dictionary to track occupied grid positions
var spawned_rooms = []
var available_doors = []

# Cache for room data from JSON
var room_data_cache = {}

var door_scene: PackedScene = preload("res://entities/interactable_door.tscn")


func _ready():
	load_room_data_from_json()


func load_room_data_from_json() -> void:
	"""Load all room data from the JSON file into a cache"""
	var file = FileAccess.open(ROT_ROOM_ASSETS_JSON, FileAccess.READ)
	if not file:
		push_error("Failed to open: " + ROT_ROOM_ASSETS_JSON)
		push_error("Make sure the rot_room_assets.json file exists!")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("Failed to parse JSON: " + ROT_ROOM_ASSETS_JSON)
		return
	
	var data = json.get_data()
	
	# Handle the format: {"rooms": [...]}
	var rooms_array = []
	if data is Dictionary and data.has("rooms"):
		rooms_array = data["rooms"]
	else:
		push_error("Invalid JSON format - expected {rooms: array}")
		return
	
	# Build a lookup dictionary by room name
	for room in rooms_array:
		room_data_cache[room["name"]] = room
	
	print("Loaded ", room_data_cache.size(), " room variants from JSON")


func get_base_room_name(room_name: String) -> String:
	"""Extract base room name without rotation suffix"""
	var base_name = room_name
	if base_name.ends_with("_rot90"):
		base_name = base_name.replace("_rot90", "")
	elif base_name.ends_with("_rot180"):
		base_name = base_name.replace("_rot180", "")
	elif base_name.ends_with("_rot270"):
		base_name = base_name.replace("_rot270", "")
	return base_name


func is_room_variant_spawned(room_name: String) -> bool:
	"""Check if any variant of this room is already spawned"""
	var base_name = get_base_room_name(room_name)
	for room_data in spawned_rooms:
		if get_base_room_name(room_data["name"]) == base_name:
			return true
	return false


func spawn_starting_room(starting_room_name: String = "foyer", filler_room_name: String = "hallway", number_of_connected_rooms: int = 8) -> void:
	"""Spawn the initial room(s) when the game starts"""
	print("Spawning starting room with connected rooms...")
	
	# Get room data from cache
	var room_data = room_data_cache.get(starting_room_name)
	if not room_data:
		push_error("No data found for starting room: " + starting_room_name)
		return
	
	# Spawn starting room at origin
	var starting_room = spawn_room_at_position(starting_room_name, Vector3.ZERO)
	if not starting_room:
		push_error("Failed to spawn starting room: " + starting_room_name)
		return
	
	# Mark grid positions as occupied based on room dimensions from JSON
	var start_pos = Vector3.ZERO
	mark_room_in_grid(start_pos, room_data)
	
	# Get doors from the spawned room and store their world positions
	var doors = get_room_doors(starting_room)
	for door in doors:
		door["world_position"] = door["node"].global_position
	available_doors = doors.duplicate()
	
	print("Starting room has ", available_doors.size(), " doors")
	
	# Track the spawned room
	spawned_rooms.append({
		"node": starting_room,
		"name": starting_room_name,
		"position": start_pos,
		"data": room_data
	})

	for i in range(number_of_connected_rooms):
		spawn_connected_room(filler_room_name)
	
	finished.emit()


func mark_room_in_grid(position: Vector3, room_data: Dictionary) -> void:
	"""Mark grid positions as occupied for a room with given dimensions from JSON"""
	var width = int(room_data["width"])
	var length = int(room_data["length"])
	
	# Mark all grid cells this room occupies
	for x in range(width):
		for z in range(length):
			var grid_pos = Vector3i(
				int(position.x + x * ROOM_SIZE),
				int(position.y),
				int(position.z + z * ROOM_SIZE)
			)
			grid[grid_pos] = true


func check_room_collision(position: Vector3, room_data: Dictionary) -> bool:
	"""Check if a room with given dimensions would collide with existing rooms"""
	var width = int(room_data["width"])
	var length = int(room_data["length"])
	
	for x in range(width):
		for z in range(length):
			var grid_pos = Vector3i(
				int(position.x + x * ROOM_SIZE),
				int(position.y),
				int(position.z + z * ROOM_SIZE)
			)
			if grid.has(grid_pos):
				return true
	return false


func calculate_door_world_position(room_position: Vector3, room_data: Dictionary, direction: String, door_index: int) -> Vector3:
	"""Calculate where a door would be in world space based on room data"""
	var width = int(room_data["width"])
	var length = int(room_data["length"])
	
	# Door positions are indices along the wall
	# We need to convert these to world positions
	var door_pos = Vector3(room_position)
	
	match direction:
		"north":
			# North wall is at z = 0, doors along x-axis
			door_pos.x += door_index * ROOM_SIZE
			door_pos.z += 0
		"south":
			# South wall is at z = length * ROOM_SIZE, doors along x-axis
			door_pos.x += door_index * ROOM_SIZE
			door_pos.z += length * ROOM_SIZE
		"east":
			# East wall is at x = width * ROOM_SIZE, doors along z-axis
			door_pos.x += width * ROOM_SIZE
			door_pos.z += door_index * ROOM_SIZE
		"west":
			# West wall is at x = 0, doors along z-axis
			door_pos.x += 0
			door_pos.z += door_index * ROOM_SIZE
	
	return door_pos


func calculate_room_position_from_door_alignment(parent_door_world_pos: Vector3, parent_door_direction: String, 
												   room_data: Dictionary, child_door_direction: String, child_door_index: int) -> Vector3:
	"""Calculate where a room should be positioned so its door aligns with the parent door"""
	
	# Calculate where the child door would be if the room was at origin
	var child_door_offset = calculate_door_world_position(Vector3.ZERO, room_data, child_door_direction, child_door_index)
	
	# The room position is: parent_door_position - child_door_offset
	var room_position = parent_door_world_pos - child_door_offset
	
	return room_position


func spawn_connected_room(filler_room_name: String = "none") -> void:
	if available_doors.is_empty():
		print("No available doors to spawn connected room")
		return

	# Select a random available door
	var parent_door = available_doors[randi() % available_doors.size()]
	var parent_door_position = parent_door["world_position"]
	var parent_door_direction = parent_door["direction"]
	
	print("Spawning connected room at door: ", parent_door["name"], " at position ", parent_door_position)

	# Get opposing direction
	var opposing_direction = get_opposing_direction(parent_door_direction)
	
	# Try multiple times to find a room that doesn't collide
	var max_attempts = 10
	var room_placed = false
	
	for attempt in range(max_attempts):
		# Find a room with opposing door using JSON data ONLY
		var room_candidate = find_room_with_door_in_direction(opposing_direction)
		if not room_candidate:
			print("Could not find room with door in direction: ", opposing_direction)
			break
		
		var room_name = room_candidate["name"]
		var room_data = room_candidate["data"]
		
		# Get the first door in the opposing direction from JSON
		var child_door_positions = room_data["doors"][opposing_direction]
		if child_door_positions.is_empty():
			continue
		
		# Try the first door (could be randomized if multiple doors exist)
		var child_door_index = int(child_door_positions[0])
		
		# Calculate where this room would be positioned based on PURE JSON DATA
		var calculated_position = calculate_room_position_from_door_alignment(
			parent_door_position,
			parent_door_direction,
			room_data,
			opposing_direction,
			child_door_index
		)
		
		print("  Attempt ", attempt + 1, ": ", room_name, " would be at ", calculated_position)
		
		# Check for collisions using PURE JSON DATA (no room loading!)
		if check_room_collision(calculated_position, room_data):
			print("    ✗ Collision detected")
			continue  # Try again with a different room
		
		# NO COLLISION! Now we can actually spawn the room
		print("    ✓ No collision - spawning room")
		var new_room = spawn_room_at_position(room_name, calculated_position)
		if not new_room:
			print("    ✗ Failed to spawn room: ", room_name)
			continue
		
		# Mark grid positions as occupied
		mark_room_in_grid(calculated_position, room_data)
		
		print("Successfully placed room: ", room_name, " at ", calculated_position)
		
		# Track the spawned room
		spawned_rooms.append({
			"node": new_room,
			"name": room_name,
			"position": calculated_position,
			"data": room_data
		})
		
		# Get door nodes from the newly spawned room
		var new_room_doors = get_room_doors(new_room)
		var child_door = null
		
		# Find the connecting door
		for door in new_room_doors:
			if door["direction"] == opposing_direction:
				child_door = door
				break
		
		if not child_door:
			push_error("Could not find child door in spawned room - this shouldn't happen!")
			continue
		
		# Store world position for this door
		child_door["world_position"] = child_door["node"].global_position
		
		# Enable door visibility and disable walls
		set_door_visible(parent_door, true)
		set_door_visible(child_door, true)
		disable_wall_at_door(parent_door)
		disable_wall_at_door(child_door)
		
		# Spawn door entity
		var door_node: Node3D = door_scene.instantiate()
		get_parent().add_child(door_node)
		door_node.global_position = parent_door_position
		
		if parent_door_direction == "east" or parent_door_direction == "west":
			door_node.rotation.y = PI / 2.0 
		
		# Add new doors to available_doors (excluding the connection door)
		for door in new_room_doors:
			if door["name"] != child_door["name"]:
				door["world_position"] = door["node"].global_position
				available_doors.append(door)
		
		available_doors.erase(parent_door)
		print("Available doors count: ", available_doors.size())
		room_placed = true
		break
	
	# If no room was placed after all attempts, spawn a filler room
	if not room_placed and filler_room_name and filler_room_name != "none":
		print("Spawning filler room: ", filler_room_name)
		spawn_filler_room(parent_door, opposing_direction, filler_room_name)


func find_room_with_door_in_direction(direction: String) -> Dictionary:
	"""Find a random room from JSON data that has a door in the specified direction"""
	var available_rooms = []
	
	# Filter rooms that have a door in the required direction and aren't already spawned
	for room_name in room_data_cache.keys():
		if is_room_variant_spawned(room_name):
			continue
		
		var room_data = room_data_cache[room_name]
		if has_door_in_direction_from_data(room_data, direction):
			available_rooms.append({
				"name": room_name,
				"data": room_data
			})
	
	if available_rooms.is_empty():
		return {}
	
	# Return a random room from the available ones
	return available_rooms[randi() % available_rooms.size()]


func has_door_in_direction_from_data(room_data: Dictionary, direction: String) -> bool:
	"""Check if room data indicates a door in the specified direction"""
	if not room_data.has("doors"):
		return false
	
	var doors = room_data["doors"]
	if not doors.has(direction):
		return false
	
	return doors[direction].size() > 0


func spawn_filler_room(parent_door: Dictionary, opposing_direction: String, filler_room_name: String) -> void:
	"""Spawn a filler room when no suitable room is found"""
	var filler_candidate = find_filler_room_with_door(filler_room_name, opposing_direction)
	if not filler_candidate:
		print("Could not find filler room variant with required door")
		available_doors.erase(parent_door)
		return
	
	var room_name = filler_candidate["name"]
	var room_data = filler_candidate["data"]
	var parent_door_position = parent_door["world_position"]
	
	# Get the first door in the opposing direction
	var child_door_positions = room_data["doors"][opposing_direction]
	if child_door_positions.is_empty():
		available_doors.erase(parent_door)
		return
	
	var child_door_index = int(child_door_positions[0])
	
	# Calculate position using JSON data
	var calculated_position = calculate_room_position_from_door_alignment(
		parent_door_position,
		parent_door["direction"],
		room_data,
		opposing_direction,
		child_door_index
	)
	
	# Check for collisions
	if check_room_collision(calculated_position, room_data):
		print("Filler room would collide - removing door from available")
		available_doors.erase(parent_door)
		return
	
	# Spawn the filler room
	var new_room = spawn_room_at_position(room_name, calculated_position)
	if not new_room:
		print("Failed to spawn filler room: ", room_name)
		available_doors.erase(parent_door)
		return
	
	# Mark grid positions
	mark_room_in_grid(calculated_position, room_data)
	
	print("Successfully placed filler room: ", room_name, " at ", calculated_position)
	
	# Track the spawned room
	spawned_rooms.append({
		"node": new_room,
		"name": room_name,
		"position": calculated_position,
		"data": room_data
	})
	
	# Get door nodes
	var new_room_doors = get_room_doors(new_room)
	var child_door = null
	for door in new_room_doors:
		if door["direction"] == opposing_direction:
			child_door = door
			break
	
	if not child_door:
		available_doors.erase(parent_door)
		return
	
	child_door["world_position"] = child_door["node"].global_position
	
	# Enable door visibility and disable walls
	set_door_visible(parent_door, true)
	set_door_visible(child_door, true)
	disable_wall_at_door(parent_door)
	disable_wall_at_door(child_door)
	
	# Spawn door entity
	var door_node: Node3D = door_scene.instantiate()
	get_parent().add_child(door_node)
	door_node.global_position = parent_door_position
	
	if parent_door["direction"] == "east" or parent_door["direction"] == "west":
		door_node.rotation.y = PI / 2.0 
	
	# Add new doors to available_doors
	for door in new_room_doors:
		if door["name"] != child_door["name"]:
			door["world_position"] = door["node"].global_position
			available_doors.append(door)
	
	available_doors.erase(parent_door)


func find_filler_room_with_door(filler_room_name: String, direction: String) -> Dictionary:
	"""Find a filler room variant that has a door in the specified direction"""
	var rotations = ["", "_rot90", "_rot180", "_rot270"]
	
	for rot in rotations:
		var room_name = filler_room_name + rot
		if room_data_cache.has(room_name):
			var room_data = room_data_cache[room_name]
			if has_door_in_direction_from_data(room_data, direction):
				return {
					"name": room_name,
					"data": room_data
				}
	
	return {}


func set_door_visible(door_info: Dictionary, door_visible: bool) -> void:
	"""Set the visibility of a door node"""
	if not door_info.has("node"):
		return
	
	var door_node = door_info["node"]
	if door_node:
		door_node.visible = door_visible


func disable_wall_at_door(door_info: Dictionary) -> void:
	"""Disable the wall corresponding to a door"""
	if not door_info.has("node") or not door_info.has("room"):
		return

	var room_node = door_info["room"]
	var door_name = door_info["name"]
	
	# Extract the wall name pattern (e.g., "DoorNorth0" -> "WallNorth0")
	var wall_name = door_name.replace("Door", "Wall")
	
	# Find the corresponding wall
	var walls_node = room_node.get_node_or_null("Walls")
	if not walls_node:
		return
	
	var wall_node = walls_node.get_node_or_null(wall_name)
	if wall_node:
		wall_node.queue_free()


func get_opposing_direction(direction: String) -> String:
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
	return ""


func spawn_room_at_position(room_name: String, pos: Vector3) -> Node3D:
	"""Spawn a specific room at a given position - ONLY CALLED WHEN WE'RE SURE IT FITS"""
	var scene_path = ROT_ROOMS_PATH + room_name + ".tscn"
	
	# Check if the scene file exists
	if not ResourceLoader.exists(scene_path):
		print("Room scene not found: ", scene_path)
		return null
	
	# Load and instance the room scene
	var room_scene = load(scene_path)
	if not room_scene:
		print("Failed to load room scene: ", scene_path)
		return null
	
	var room_instance = room_scene.instantiate()
	if not room_instance:
		print("Failed to instantiate room: ", scene_path)
		return null
	
	# Add the room to the parent scene
	get_parent().add_child(room_instance)
	
	# Set the room position
	room_instance.global_position = pos
	
	return room_instance


func get_room_doors(room_node: Node3D) -> Array:
	"""Get all door nodes from a room as a list of dictionaries with direction, name, and node"""
	var door_list = []
	
	if not room_node:
		return door_list
	
	var walls_node = room_node.get_node_or_null("Walls")
	if not walls_node:
		return door_list
	
	# Search for door nodes by name pattern
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
			door_list.append({
				"room": room_node,
				"direction": direction,
				"name": str(node_name),
				"node": child
			})
	
	return door_list
