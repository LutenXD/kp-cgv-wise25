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

func spawn_room(room_scene_path: String = "res://assets/rooms/grand_foyer.tscn", position: Vector3 = Vector3.ZERO):
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
	
	room_instance.global_position = position
	room_instance.name = "Room_" + room_scene_path.get_file().get_basename()
	
	add_child(room_instance)
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
	else:
		push_error("Failed to spawn starting room!")
	return room
