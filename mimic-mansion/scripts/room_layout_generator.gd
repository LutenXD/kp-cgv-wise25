extends Node3D

# Grid-based room layout generator with tree structure
# Each tile is 2x2 meters

const TILE_SIZE = 2.0  # Each grid tile is 2x2 meters

# Room templates with tile dimensions and doorway positions
# Doorways are defined as: {"side": "north/south/east/west", "tile_offset": int}
const ROOM_TEMPLATES = {
	"grand_foyer": {
		"scene": "res://scenes/rooms/grand_foyer.tscn",
		"tiles_x": 8, "tiles_z": 10,  # 16x20m (8x10 tiles)
		"doorways": [
			{"side": "north", "tile_offset": 4},
			{"side": "south", "tile_offset": 4},
			{"side": "east", "tile_offset": 5},
			{"side": "west", "tile_offset": 5}
		]
	},
	"library": {
		"scene": "res://scenes/rooms/library.tscn",
		"tiles_x": 6, "tiles_z": 8,  # 12x16m (6x8 tiles)
		"doorways": [
			{"side": "north", "tile_offset": 3},
			{"side": "south", "tile_offset": 3},
			{"side": "east", "tile_offset": 4},
			{"side": "west", "tile_offset": 4}
		]
	},
	"dining_room": {
		"scene": "res://scenes/rooms/dining_room.tscn",
		"tiles_x": 6, "tiles_z": 8,  # 12x16m
		"doorways": [
			{"side": "north", "tile_offset": 3},
			{"side": "south", "tile_offset": 3},
			{"side": "east", "tile_offset": 4}
		]
	},
	"master_bedroom": {
		"scene": "res://scenes/rooms/master_bedroom.tscn",
		"tiles_x": 6, "tiles_z": 8,  # 12x16m
		"doorways": [
			{"side": "west", "tile_offset": 4},
			{"side": "north", "tile_offset": 3}
		]
	},
	"kitchen_pantry": {
		"scene": "res://scenes/rooms/kitchen_pantry.tscn",
		"tiles_x": 5, "tiles_z": 6,  # 10x12m
		"doorways": [
			{"side": "west", "tile_offset": 3},
			{"side": "south", "tile_offset": 2}
		]
	},
	"bathroom": {
		"scene": "res://scenes/rooms/bathroom.tscn",
		"tiles_x": 3, "tiles_z": 4,  # 6x8m
		"doorways": [
			{"side": "north", "tile_offset": 1}
		]
	},
	"wine_cellar": {
		"scene": "res://scenes/rooms/wine_cellar.tscn",
		"tiles_x": 4, "tiles_z": 5,  # 8x10m
		"doorways": [
			{"side": "north", "tile_offset": 2},
			{"side": "east", "tile_offset": 2}
		]
	},
	"music_room": {
		"scene": "res://scenes/rooms/music_room.tscn",
		"tiles_x": 5, "tiles_z": 6,  # 10x12m
		"doorways": [
			{"side": "south", "tile_offset": 2},
			{"side": "west", "tile_offset": 3}
		]
	},
	"art_gallery": {
		"scene": "res://scenes/rooms/art_gallery.tscn",
		"tiles_x": 6, "tiles_z": 8,  # 12x16m
		"doorways": [
			{"side": "east", "tile_offset": 4},
			{"side": "south", "tile_offset": 3}
		]
	},
	"attic": {
		"scene": "res://scenes/rooms/attic.tscn",
		"tiles_x": 5, "tiles_z": 6,  # 10x12m
		"doorways": [
			{"side": "south", "tile_offset": 2}
		]
	}
}

var instantiated_rooms = {}
var occupied_tiles = {}  # Track which tiles are occupied
var room_instances = []  # List of placed room data

func _ready():
	randomize()
	generate_tree_layout()

func generate_tree_layout():
	"""Generate mansion layout using tree structure"""
	print("Generating tree-based room layout...")
	
	# Clear previous layout
	clear_layout()
	
	# Start with grand foyer at origin
	var start_room = {
		"name": "grand_foyer",
		"template": ROOM_TEMPLATES["grand_foyer"],
		"tile_x": 0,
		"tile_z": 0,
		"connected_doors": []
	}
	
	place_room(start_room)
	room_instances.append(start_room)
	
	# Queue for breadth-first room placement
	var room_queue = [start_room]
	var available_room_types = ROOM_TEMPLATES.keys()
	available_room_types.erase("grand_foyer")  # Don't duplicate foyer
	
	while room_queue.size() > 0 and room_instances.size() < 15:  # Limit total rooms
		var current_room = room_queue.pop_front()
		var doorways = current_room["template"]["doorways"]
		
		# Try to connect rooms to unused doorways
		for doorway in doorways:
			if doorway in current_room["connected_doors"]:
				continue
			
			# Randomly decide if we should add a room here (create branching)
			if randf() > 0.7 and room_instances.size() >= 5:  # 30% chance to skip after 5 rooms
				continue
			
			# Try to place a new room at this doorway
			var new_room = try_place_room_at_doorway(current_room, doorway, available_room_types)
			if new_room:
				room_instances.append(new_room)
				room_queue.append(new_room)
				current_room["connected_doors"].append(doorway)
				print("Placed room: ", new_room["name"], " connected to ", current_room["name"])
	
	print("Generated ", room_instances.size(), " rooms in tree structure")

func clear_layout():
	"""Clear all existing rooms and data"""
	for child in get_children():
		child.queue_free()
	
	instantiated_rooms.clear()
	occupied_tiles.clear()
	room_instances.clear()

func place_room(room_data: Dictionary):
	"""Instantiate and place a room in the world"""
	var template = room_data["template"]
	var room_scene = load(template["scene"])
	
	if room_scene:
		var room_instance = room_scene.instantiate()
		room_instance.name = room_data["name"]
		
		# Calculate world position from tile coordinates
		var world_pos = Vector3(
			room_data["tile_x"] * TILE_SIZE,
			0,
			room_data["tile_z"] * TILE_SIZE
		)
		room_instance.position = world_pos
		
		add_child(room_instance)
		instantiated_rooms[room_data["name"]] = room_instance
		
		# Mark tiles as occupied
		mark_tiles_occupied(room_data["tile_x"], room_data["tile_z"], 
							template["tiles_x"], template["tiles_z"])
		
		print("Placed room at tiles (", room_data["tile_x"], ", ", room_data["tile_z"], ")")

func try_place_room_at_doorway(parent_room: Dictionary, doorway: Dictionary, available_types: Array) -> Dictionary:
	"""Try to place a random room connected to the given doorway"""
	# Shuffle available types for randomness
	var shuffled_types = available_types.duplicate()
	shuffled_types.shuffle()
	
	for room_type in shuffled_types:
		var template = ROOM_TEMPLATES[room_type]
		
		# Find a matching doorway on the new room
		for new_doorway in template["doorways"]:
			# Check if doorways are compatible (opposite sides)
			if not are_doorways_compatible(doorway["side"], new_doorway["side"]):
				continue
			
			# Calculate new room position
			var new_tile_pos = calculate_connected_position(
				parent_room, doorway,
				template, new_doorway
			)
			
			# Check if position is free
			if can_place_room(new_tile_pos.x, new_tile_pos.y, template["tiles_x"], template["tiles_z"]):
				var new_room = {
					"name": room_type + "_" + str(room_instances.size()),
					"template": template,
					"tile_x": new_tile_pos.x,
					"tile_z": new_tile_pos.y,
					"connected_doors": [new_doorway]
				}
				
				place_room(new_room)
				return new_room
	
	return {}  # Failed to place room

func are_doorways_compatible(side1: String, side2: String) -> bool:
	"""Check if two doorway sides can connect"""
	return (side1 == "north" and side2 == "south") or \
		   (side1 == "south" and side2 == "north") or \
		   (side1 == "east" and side2 == "west") or \
		   (side1 == "west" and side2 == "east")

func calculate_connected_position(parent_room: Dictionary, parent_door: Dictionary, 
								  new_template: Dictionary, new_door: Dictionary) -> Vector2i:
	"""Calculate tile position for new room based on doorway connection"""
	var parent_template = parent_room["template"]
	var parent_tile_x = parent_room["tile_x"]
	var parent_tile_z = parent_room["tile_z"]
	
	var new_x = parent_tile_x
	var new_z = parent_tile_z
	
	match parent_door["side"]:
		"north":
			new_z = parent_tile_z - new_template["tiles_z"]
			new_x = parent_tile_x + parent_door["tile_offset"] - new_door["tile_offset"]
		"south":
			new_z = parent_tile_z + parent_template["tiles_z"]
			new_x = parent_tile_x + parent_door["tile_offset"] - new_door["tile_offset"]
		"east":
			new_x = parent_tile_x + parent_template["tiles_x"]
			new_z = parent_tile_z + parent_door["tile_offset"] - new_door["tile_offset"]
		"west":
			new_x = parent_tile_x - new_template["tiles_x"]
			new_z = parent_tile_z + parent_door["tile_offset"] - new_door["tile_offset"]
	
	return Vector2i(new_x, new_z)

func can_place_room(tile_x: int, tile_z: int, width: int, height: int) -> bool:
	"""Check if a room can be placed at the given tile position"""
	for x in range(tile_x, tile_x + width):
		for z in range(tile_z, tile_z + height):
			var key = Vector2i(x, z)
			if occupied_tiles.has(key):
				return false
	return true

func mark_tiles_occupied(tile_x: int, tile_z: int, width: int, height: int):
	"""Mark tiles as occupied by a room"""
	for x in range(tile_x, tile_x + width):
		for z in range(tile_z, tile_z + height):
			occupied_tiles[Vector2i(x, z)] = true

func regenerate_layout():
	"""Public function to regenerate the entire layout"""
	generate_tree_layout()
