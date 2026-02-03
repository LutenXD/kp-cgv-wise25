extends Node3D
class_name RoomLayoutManager3

signal finished

const ROT_ROOMS_PATH = "res://assets/rot_rooms/"
const JSON_PATH = "res://data/rot_room_assets.json"
const TILE_SIZE = 10.0

var grid = {} 
var spawned_rooms = []
var available_doors = []
var room_metadata = {} # Cache for JSON data

var door_scene: PackedScene = preload("res://entities/interactable_door.tscn")

func _ready():
	load_room_metadata()

func load_room_metadata():
	"""Load the pre-generated JSON metadata into a dictionary for fast lookup"""
	if not FileAccess.file_exists(JSON_PATH):
		push_error("Room metadata JSON not found!")
		return
	
	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	if json_data and json_data.has("rooms"):
		for room in json_data["rooms"]:
			room_metadata[room["name"]] = room
	print("Loaded metadata for ", room_metadata.size(), " room variants.")

func spawn_starting_room(starting_room_name: String = "foyer", filler_room_name: String = "hallway", number_of_connected_rooms: int = 8) -> void:
	# 1. Initial Spawn
	var starting_room = spawn_room_at_position(starting_room_name, Vector3.ZERO)
	
	# 2. Register initial grid from Metadata (No need to loop through nodes)
	var meta = room_metadata.get(starting_room_name)
	if meta:
		for cell in meta["occupied_cells"]:
			grid[Vector3i(cell.x * TILE_SIZE, 0, cell.z * TILE_SIZE)] = true
	
	available_doors = get_room_doors(starting_room)
	
	spawned_rooms.append({"name": starting_room_name, "position": Vector3.ZERO})

	for i in range(number_of_connected_rooms):
		spawn_connected_room(filler_room_name)
	
	finished.emit()

func spawn_connected_room(filler_room_name: String = "none") -> void:
	if available_doors.is_empty(): return

	var parent_door = available_doors[randi() % available_doors.size()]
	var opposing_dir = get_opposing_direction(parent_door["direction"])
	
	# Filter potential rooms from METADATA instead of DISK
	var valid_room_names = []
	for r_name in room_metadata.keys():
		if not is_room_variant_spawned(r_name) and room_metadata[r_name]["doors"][opposing_dir].size() > 0:
			valid_room_names.append(r_name)

	valid_room_names.shuffle()

	var room_placed = false
	for room_name in valid_room_names:
		if attempt_placement(room_name, parent_door, opposing_dir):
			room_placed = true
			break
	
	if not room_placed and filler_room_name != "none":
		# Try filler variants
		for rot in ["", "_rot90", "_rot180", "_rot270"]:
			if attempt_placement(filler_room_name + rot, parent_door, opposing_dir):
				break

func attempt_placement(room_name: String, parent_door: Dictionary, opposing_dir: String) -> bool:
	var meta = room_metadata.get(room_name)
	if not meta: return false

	# Get the specific door index from JSON (e.g., the first door in that direction)
	var child_door_index = meta["doors"][opposing_dir][0]
	
	# Calculate where the room origin WOULD be based on door alignment
	# This math replaces the need to instantiate the node to check its global_pos
	var parent_door_pos = parent_door["node"].global_position
	
	# Calculate child door relative offset
	var child_door_rel_pos = Vector3.ZERO
	if opposing_dir in ["north", "south"]:
		child_door_rel_pos = Vector3(child_door_index * TILE_SIZE, 0, 0 if opposing_dir == "north" else (meta["length"] - 1) * TILE_SIZE)
	else:
		child_door_rel_pos = Vector3(0 if opposing_dir == "west" else (meta["width"] - 1) * TILE_SIZE, 0, child_door_index * TILE_SIZE)
		
	var target_origin = parent_door_pos - child_door_rel_pos
	target_origin = target_origin.round()

	# VIRTUAL COLLISION CHECK
	for cell in meta["occupied_cells"]:
		var check_pos = Vector3i(
			target_origin.x + (cell.x * TILE_SIZE),
			0,
			target_origin.z + (cell.z * TILE_SIZE)
		)
		if grid.has(check_pos):
			return false # Collision!
	
	# SUCCESS: Now we instantiate
	var new_room = spawn_room_at_position(room_name, target_origin)
	
	# Update Grid
	for cell in meta["occupied_cells"]:
		var final_pos = Vector3i(target_origin.x + (cell.x * TILE_SIZE), 0, target_origin.z + (cell.z * TILE_SIZE))
		grid[final_pos] = true
	
	# Setup Doors (Visuals/Walls)
	finalize_connection(new_room, room_name, parent_door)
	return true

func finalize_connection(new_room, room_name, parent_door):
	var new_doors = get_room_doors(new_room)
	var opposing_dir = get_opposing_direction(parent_door["direction"])
	
	# Find the door node on the new room that connects back to parent
	var connection_door = null
	for d in new_doors:
		if d["direction"] == opposing_dir:
			connection_door = d
			break
			
	if connection_door:
		set_door_visible(parent_door, true)
		set_door_visible(connection_door, true)
		disable_wall_at_door(parent_door)
		disable_wall_at_door(connection_door)
		
		# Spawn physical door entity
		var door_ent = door_scene.instantiate()
		get_parent().add_child(door_ent)
		door_ent.global_position = parent_door["node"].global_position
		if parent_door["direction"] in ["east", "west"]:
			door_ent.rotation.y = PI / 2.0
			
		# Update available list
		for d in new_doors:
			if d["node"] != connection_door["node"]:
				available_doors.append(d)
	
	available_doors.erase(parent_door)
	spawned_rooms.append({"name": room_name, "position": new_room.global_position})
