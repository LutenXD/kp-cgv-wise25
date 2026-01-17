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
		room_data[room["name"]] = room
	
	print("Loaded ", room_data.size(), " room definitions")

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
	
	var room_scene = ResourceLoader.load(room_scene_path, "", ResourceLoader.CACHE_MODE_REUSE)
	
	if not room_scene:
		var error = ResourceLoader.load_threaded_get_status(room_scene_path)
		push_error("Failed to load room scene: " + room_scene_path + " Error: " + str(error))
		return null

	var room_instance = room_scene.instantiate()
	
	if not room_instance:
		push_error("Failed to instantiate room")
		return null
	
	room_instance.name = "Room_" + room_scene_path.get_file().get_basename()
	
	add_child(room_instance)
	
	room_instance.global_position = position
	room_instance.rotation_degrees.y = rotation_degrees
	
	return room_instance

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
	var offset = Vector3.ZERO
	match door_direction:
		"north":
			# New room connects to parent's north side, extends northward (-Z)
			offset = Vector3(0, 0, -(parent_dimensions.y + new_dimensions.y) * grid_size * 0.5)
		"east":
			# New room connects to parent's east side, extends eastward (+X)
			offset = Vector3((parent_dimensions.x + new_dimensions.x) * grid_size * 0.5, 0, 0)
		"south":
			# New room connects to parent's south side, extends southward (+Z)
			offset = Vector3(0, 0, (parent_dimensions.y + new_dimensions.y) * grid_size * 0.5)
		"west":
			# New room connects to parent's west side, extends westward (-X)
			offset = Vector3(-(parent_dimensions.x + new_dimensions.x) * grid_size * 0.5, 0, 0)
	
	# Apply parent rotation to the offset
	var rotated_offset = offset.rotated(Vector3.UP, deg_to_rad(parent_rotation))
	var new_room_position = parent_position + rotated_offset
	
	# New room faces opposite direction to parent's door
	var opposing_directions = {"north": "south", "south": "north", "east": "west", "west": "east"}
	var new_room_facing = opposing_directions[door_direction]
	var direction_angles = {"north": 0.0, "east": 90.0, "south": 180.0, "west": 270.0}
	var new_room_rotation = direction_angles[new_room_facing]
	
	print("  Parent: ", parent_room_name, " (", parent_dimensions.x, "x", parent_dimensions.y, ") at ", parent_position)
	print("  New: ", selected_room_name, " (", new_dimensions.x, "x", new_dimensions.y, ") at ", new_room_position)
	print("  Door direction: ", door_direction, " -> New room facing: ", new_room_facing)
	
	# Spawn the room
	var room_scene_path = "res://assets/rooms/" + selected_room_name + ".tscn"
	var new_room = spawn_room(room_scene_path, new_room_position, 0.0)
	
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
			"rotation_degrees": new_room_rotation,
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
	
