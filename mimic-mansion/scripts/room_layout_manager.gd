extends Node3D
class_name RoomLayoutManager

# Configuration
const STARTING_ROOM_PATH = "res://assets/rot_rooms/grand_foyer.tscn"
const STARTING_ROOM_POSITION = Vector3.ZERO
const ROOM_ASSETS_PATH = "res://data/rot_room_assets.json"

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

func disable_wall(room_instance: Node3D, direction: String, wall_index: int):
	"""Disable (hide) a specific wall in a room and remove its collision"""
	var walls_node = room_instance.get_node_or_null("Walls")
	if not walls_node:
		return
	
	var wall_name = "Wall" + direction.capitalize() + str(wall_index)
	var wall_node = walls_node.get_node_or_null(wall_name)
	if wall_node:
		# Remove the collision shape so players can pass through
		var collision_shape = wall_node.get_node_or_null("CollisionShape3D")
		if collision_shape:
			collision_shape.queue_free()
		# Hide the wall visually
		wall_node.visible = false
		print("  Disabled wall (removed collision): ", wall_name)

func enable_door(room_instance: Node3D, direction: String, door_index: int):
	"""Enable (show) a specific door in a room"""
	var walls_node = room_instance.get_node_or_null("Walls")
	if not walls_node:
		return
	
	var door_name = "Door" + direction.capitalize() + str(door_index)
	var door_node = walls_node.get_node_or_null(door_name)
	if door_node:
		door_node.visible = true
		print("  Enabled door: ", door_name)

func spawn_room(room_scene_path: String = "res://assets/rot_rooms/grand_foyer.tscn", position: Vector3 = Vector3.ZERO):
	"""Spawn a single room in the scene"""
	
	var room_name = room_scene_path.get_file().get_basename()
	
	var room_scene = ResourceLoader.load(room_scene_path, "", ResourceLoader.CACHE_MODE_REUSE)
	
	if not room_scene:
		var error = ResourceLoader.load_threaded_get_status(room_scene_path)
		push_error("Failed to load room scene: " + room_scene_path + " Error: " + str(error))
		return null

	var room_instance = room_scene.instantiate()
	
	if not room_instance:
		push_error("Failed to instantiate room")
		return null
	
	room_instance.name = "Room_" + room_name
	
	add_child(room_instance)
	
	room_instance.global_position = position
	
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

func restore_room_layout(saved_rooms: Array):
	"""Restore previously spawned rooms from saved data"""
	print("RoomLayoutManager: Restoring ", saved_rooms.size(), " saved rooms...")
	
	spawned_rooms.clear()
	
	for room_data_dict in saved_rooms:
		var room_name = room_data_dict.get("name", "")
		var position = room_data_dict.get("position", Vector3.ZERO)
		var scene_path = room_data_dict.get("scene_path", "")
		
		# Spawn the room at saved position
		var room = spawn_room(scene_path, position)
		
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

	# Use the selected room name (with rotation suffix) as the scene path
	var room_scene_path = "res://assets/rot_rooms/" + selected_room_name + ".tscn"
	
	# Check if the scene file exists before trying to load it
	if not ResourceLoader.exists(room_scene_path):
		push_error("Room scene file does not exist: " + room_scene_path)
		print("  Skipping room: ", selected_room_name, " (file not found)")
		return null
	
	var new_room = spawn_room(room_scene_path, Vector3.ZERO)
	
	if new_room:
		# Disable connecting walls and enable connecting doors
		var opposing_dirs = {
			"north": "south", "south": "north", 
			"east": "west", "west": "east"
		}
		
		var opposing_door_direction = opposing_dirs[door_direction]
		var parent_door_index = int(door_info["door_info"])
		
		# Get parent room's door position
		var parent_room_node = get_node_or_null("Room_" + parent_room_name)
		var parent_door_global_pos = Vector3.ZERO
		
		if parent_room_node:
			var parent_walls_node = parent_room_node.get_node_or_null("Walls")
			if parent_walls_node:
				var parent_door_name = "Door" + door_direction.capitalize() + str(parent_door_index)
				var parent_door_node = parent_walls_node.get_node_or_null(parent_door_name)
				if parent_door_node:
					parent_door_global_pos = parent_door_node.global_position
					print("  Parent door global position: ", parent_door_global_pos)
		
		# Get new room's connecting door position (before positioning the room)
		var new_walls_node = new_room.get_node_or_null("Walls")
		var new_door_local_pos = Vector3.ZERO
		
		if new_walls_node:
			var new_door_name = "Door" + opposing_door_direction.capitalize() + "0"
			var new_door_node = new_walls_node.get_node_or_null(new_door_name)
			if new_door_node:
				new_door_local_pos = new_door_node.position
				print("  New room door local position: ", new_door_local_pos)
		
		# Calculate the new room's position so doors align
		var new_room_position = parent_door_global_pos - new_door_local_pos
		new_room.global_position = new_room_position
		print("  Positioned new room at: ", new_room_position)
		
		# Now disable walls and enable doors at connection points
		if parent_room_node:
			disable_wall(parent_room_node, door_direction, parent_door_index)
			enable_door(parent_room_node, door_direction, parent_door_index)
		
		disable_wall(new_room, opposing_door_direction, 0)
		enable_door(new_room, opposing_door_direction, 0)
		
		print("  Connected rooms via doors: ", door_direction, " <-> ", opposing_door_direction)


		# Track the new room
		var doors = get_room_doors(selected_room_name)
		spawned_rooms.append({
			"name": selected_room_name,
			"position": new_room_position,
			"unused_doors": doors
		})
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
	
