extends Node3D
class_name RoomLayoutManager


signal finished

# Path to the rotated rooms folder
const ROT_ROOMS_PATH = "res://assets/rot_rooms/"

# Grid settings for room placement
const ROOM_SIZE = 10.0  # Base size of a room (10x10 units)
var grid = {}  # Dictionary to track occupied grid positions
var spawned_rooms = []
var available_doors = []

var door_scene: PackedScene = preload("res://entities/interactable_door.tscn")


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

func spawn_starting_room(starting_room_name: String = "grand_foyer", filler_room_name: String = "hallway", number_of_connected_rooms: int = 6) -> void:
	"""Spawn the initial room(s) when the game starts"""
	print("Spawning starting room with connected rooms...")
	
	# Spawn grand foyer as the starting room at origin
	var starting_room = spawn_room_at_position(starting_room_name, Vector3.ZERO)
	grid[Vector3i(0, 0, 0)] = true


	var doors = get_room_doors(starting_room)
	available_doors = doors.duplicate()
	
	for floor_tile in get_floor_tiles_in_room(starting_room):
		var floor_grid_position = Vector3i(floor_tile.global_position.x, floor_tile.global_position.y, floor_tile.global_position.z)
		grid[floor_grid_position] = true
	
	# Track the spawned room
	spawned_rooms.append({
		"node": null,
		"name": starting_room_name,
		"position": Vector3.ZERO
	})

	for i in range(number_of_connected_rooms):
		spawn_connected_room(filler_room_name)
	
	finished.emit()
	#prints("\n", grid)
	#prints("\n", spawned_rooms)


func spawn_connected_room(filler_room_name: String = "none") -> void:

	if available_doors.is_empty():
		print("No available doors to spawn connected room")
		return

	# Select a random available door
	var parent_door = available_doors[randi() % available_doors.size()]
	print("Spawning connected room at door: ", parent_door)

	# Get opposing direction
	var opposing_direction = get_opposing_direction(parent_door["direction"])
	
	# Try multiple times to find a room that doesn't collide
	var max_attempts = 10
	var room_placed = false
	
	for attempt in range(max_attempts):
		# Find a room with opposing door
		var room_with_door = get_room_with_door_in_direction(opposing_direction)
		if not room_with_door:
			print("Could not find room with door in direction: ", opposing_direction)
			break
		
		var new_room = room_with_door["room"]
		var new_room_name = room_with_door["name"]
		
		# Store the original rotation to preserve it after position adjustment
		#var original_rotation = new_room.rotation
		#print("new_room original rotation: ", original_rotation)

		var parent_door_position = parent_door["node"].global_position
		var child_door_position = room_with_door["door"]["node"].global_position
		
		#printt("parent door pos:", parent_door_position)
		#printt("child door pos:", child_door_position)
		#printt("global pos:", new_room.global_position)
		
		#new_room.global_transform = parent_door_position * child_door_position.affine_inverse()
		new_room.global_position = parent_door_position - (child_door_position - new_room.global_position)

		# Check for collisions
		var collision_detected = false
		var new_room_floor_tiles = get_floor_tiles_in_room(new_room)
		for floor_tile in new_room_floor_tiles:
			var floor_grid_position = Vector3i(
				round(floor_tile.global_position.x), 
				round(floor_tile.global_position.y), 
				round(floor_tile.global_position.z)
			)
			if grid.has(floor_grid_position):
				print("Collision detected at grid position: ", floor_grid_position, " (attempt ", attempt + 1, ")")
				collision_detected = true
				break
		
		if collision_detected:
			new_room.queue_free()
			continue  # Try again with a different room
		else:
			# No collision - add floor tiles to grid and keep the room
			for floor_tile in new_room_floor_tiles:
				var floor_grid_position = Vector3i(
					round(floor_tile.global_position.x), 
					round(floor_tile.global_position.y), 
					round(floor_tile.global_position.z)
				)
				printt("grid pos:", floor_grid_position)
				grid[floor_grid_position] = true
			
			print("Successfully placed room: ", new_room_name)
			
			# Track the spawned room
			spawned_rooms.append({
				"node": null,
				"name": new_room_name,
				"position": Vector3.ZERO
			})
			
			# Room position confirmed, now enable door visibility and disable walls
			set_door_visible(parent_door, true)
			set_door_visible(room_with_door["door"], true)
			disable_wall_at_door(parent_door)
			disable_wall_at_door(room_with_door["door"])
			
			# Spawn door
			var door_node: Node3D = door_scene.instantiate()
			get_parent().add_child(door_node)
			door_node.global_position = parent_door_position
			
			if parent_door["direction"] == "east" or parent_door["direction"] == "west":
				door_node.rotation.y = PI / 2.0 
			
			var new_doors = get_room_doors(new_room)
			for door in new_doors:
				# Exclude the door used for connection
				if door["name"] != room_with_door["door"]["name"]:
					available_doors.append(door)
			
			available_doors.erase(parent_door)
			print("Available doors count: ", available_doors.size())
			room_placed = true
			break
	
	# If no room was placed after all attempts, spawn a filler room
	if not room_placed and filler_room_name and filler_room_name != "none":
		print("Spawning filler room: ", filler_room_name)
		spawn_filler_room(parent_door, opposing_direction, filler_room_name)

func spawn_filler_room(parent_door: Dictionary, opposing_direction: String, filler_room_name: String) -> void:
	"""Spawn a filler room when no suitable room is found"""
	var filler_room = get_filler_room_with_door(filler_room_name, opposing_direction)
	if not filler_room:
		print("Could not load filler room: ", filler_room_name)
		return
	
	var new_room = filler_room["room"]
	var new_room_name = filler_room["name"]
	
	var parent_door_position = parent_door["node"].global_position
	var child_door_position = filler_room["door"]["node"].global_position
	
	new_room.global_position = parent_door_position - (child_door_position - new_room.global_position)
	
	# Check for collisions
	var collision_detected = false
	var new_room_floor_tiles = get_floor_tiles_in_room(new_room)
	for floor_tile in new_room_floor_tiles:
		var floor_grid_position = Vector3i(
			round(floor_tile.global_position.x), 
			round(floor_tile.global_position.y), 
			round(floor_tile.global_position.z)
		)
		if grid.has(floor_grid_position):
			print("Filler room collision detected at: ", floor_grid_position)
			collision_detected = true
			break
	
	if collision_detected:
		new_room.queue_free()
		print("Could not place filler room due to collision")
		return
	
	# Add floor tiles to grid
	for floor_tile in new_room_floor_tiles:
		var floor_grid_position = Vector3i(
			round(floor_tile.global_position.x), 
			round(floor_tile.global_position.y), 
			round(floor_tile.global_position.z)
		)
		grid[floor_grid_position] = true
	
	print("Successfully placed filler room: ", new_room_name)
	
	# Track the spawned room
	spawned_rooms.append({
		"node": null,
		"name": new_room_name,
		"position": Vector3.ZERO
	})
	
	# Enable door visibility and disable walls
	set_door_visible(parent_door, true)
	set_door_visible(filler_room["door"], true)
	disable_wall_at_door(parent_door)
	disable_wall_at_door(filler_room["door"])
	
	# Add new doors to available_doors (excluding the connection door)
	var new_doors = get_room_doors(new_room)
	for door in new_doors:
		if door["name"] != filler_room["door"]["name"]:
			available_doors.append(door)
	
	available_doors.erase(parent_door)

func get_filler_room_with_door(filler_room_name: String, direction: String) -> Dictionary:
	"""Get a filler room with a door in the specified direction"""
	# Try all rotation variants of the filler room
	var rotations = ["", "_rot90", "_rot180", "_rot270"]
	
	for rot in rotations:
		var room_name = filler_room_name + rot
		var temp_room = spawn_room_at_position(room_name, Vector3.ZERO)
		
		if temp_room and has_door_in_direction(temp_room, direction):
			var room_doors = get_room_doors(temp_room)
			var door_in_direction = null
			for door in room_doors:
				if door["direction"] == direction:
					door_in_direction = door
					break
			return {
				"room": temp_room,
				"name": room_name,
				"door": door_in_direction
			}
		elif temp_room:
			temp_room.queue_free()
	
	return {}

func set_door_visible(door_info: Dictionary, door_visible: bool) -> void:
	"""Set the visibility of a door node"""
	if not door_info.has("node"):
		return
	
	var door_node = door_info["node"]
	if door_node:
		door_node.visible = door_visible
		print("Set door ", door_info["name"], " visible: ", door_visible)

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
		print("Disabled wall: ", wall_name)

func get_floor_tiles_in_room(room_node: Node3D) -> Array:
	"""Get all floor tile nodes from a room"""
	var floor_tiles = []
	
	if not room_node:
		return floor_tiles
	
	var floors_node = room_node.get_node_or_null("Floor")
	if not floors_node:
		return floor_tiles
	
	for child in floors_node.get_children():
		floor_tiles.append(child)
	
	return floor_tiles

func get_opposing_direction(direction: String) -> String:
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
	return ""

func get_room_with_door_in_direction(direction: String) -> Dictionary:
	"""Find a random room that has a door in the specified direction
	Returns a Dictionary with 'room' (Node3D) and 'name' (String), or empty dict if not found"""
	
	# Get list of all room files
	var dir = DirAccess.open(ROT_ROOMS_PATH)
	if not dir:
		print("Failed to open rot_rooms directory")
		return {}

	var room_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			room_files.append(file_name.replace(".tscn", ""))
		file_name = dir.get_next()
	dir.list_dir_end()

	if room_files.is_empty():
		print("No room files found in rot_rooms")
		return {}

	# Try to find a room with the required door
	var max_attempts = 10
	
	for attempt in range(max_attempts):
		var room_name = room_files[randi() % room_files.size()]
		
		# Skip if this room variant is already spawned
		if is_room_variant_spawned(room_name):
			continue
		
		# Load the room temporarily to check its doors
		var temp_room = spawn_room_at_position(room_name, Vector3.ZERO)
		if temp_room and has_door_in_direction(temp_room, direction):
			var room_doors = get_room_doors(temp_room)  # Preload doors
			var door_in_direction = null
			for door in room_doors:
				if door["direction"] == direction:
					door_in_direction = door
					break
			return {
				"room": temp_room,
				"name": room_name,
				"door": door_in_direction
			}
		elif temp_room:
			temp_room.queue_free()

	return {}

func spawn_room_at_position(room_name: String, pos: Vector3) -> Node3D:
	"""Spawn a specific room at a given position"""
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
	
	# Extract rotation from room name and apply it AFTER adding to scene tree
	var rot_degrees := 0.0
	if room_name.ends_with("_rot90"):
		rot_degrees = 90.0
	elif room_name.ends_with("_rot180"):
		rot_degrees = 180.0
	elif room_name.ends_with("_rot270"):
		rot_degrees = 270.0
	
	if rot_degrees > 0.0:
		room_instance.rotation_degrees.y = rot_degrees
		print("Applied rotation: ", rot_degrees, "° to room: ", room_name)
	
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

func has_door_in_direction(room_node: Node3D, direction: String) -> bool:
	"""Check if a room has a door in a specific direction (north/south/east/west)"""
	var doors = get_room_doors(room_node)
	for door in doors:
		if door["direction"] == direction:
			return true
	return false

func get_door_count(room_node: Node3D) -> int:
	"""Get the total number of doors in a room"""
	var doors = get_room_doors(room_node)
	var count = 0
	for direction in doors.keys():
		count += doors[direction].size()
	return count
