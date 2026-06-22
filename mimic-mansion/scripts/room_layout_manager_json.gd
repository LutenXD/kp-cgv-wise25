extends Node3D
#class_name RoomLayoutManager


signal finished


const ROOM_DATA_PATH := "res://data/room_assets.json"
const ROOM_SIZE: float = 10.0

## Maps each direction to the face a connecting room must expose.
const OPPOSITE_DIR: Dictionary = {
	"north": "south",
	"south": "north",
	"east":  "west",
	"west":  "east",
}


var grid: Dictionary[Vector3i, bool] = {}
var available_doors: Array[Node3D] = []
var door_scene: PackedScene = preload("res://entities/interactable_door.tscn")
var rooms: Array[Array] = []           ## [scene: String, tile_origin: Vector3i, name: String]
var room_database: Dictionary = {}
var open_doors: Array[Dictionary] = [] ## BFS queue of pending door connections


func _ready() -> void:
	randomize()


# ── Public API ────────────────────────────────────────────────────────────────

func spawn_starting_room(
		starting_room_name: String = "foyer",
		filler_room_name:   String = "hallway",
		number_of_connected_rooms: int = 8) -> void:
	load_room_database()
	add_room_to_dic(starting_room_name, Vector3i(0, 0, 0))
	generate_layout(starting_room_name, number_of_connected_rooms, filler_room_name)
	spawn_rooms()
	finished.emit()


# ── Database ──────────────────────────────────────────────────────────────────

func load_room_database() -> void:
	var file := FileAccess.open(ROOM_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to load room database")
		return

	var json := JSON.new()
	print("Parsing room database…")

	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse room database")
		return

	room_database = json.data["rooms"]
	print("Loaded %d room variants." % room_database.size())


func add_room_to_dic(room_name: String, pos: Vector3i) -> void:
	if not room_database.has(room_name):
		push_error("Room not found in database: " + room_name)
		return

	var room: Dictionary = room_database[room_name]
	rooms.append([room["scene"], pos, room_name])

	# Mark every tile this room occupies in world-tile space.
	for tile in room["occupied_tiles"]:
		grid[Vector3i(pos.x + int(tile[0]), 0, pos.z + int(tile[1]))] = true


# ── Layout generation ─────────────────────────────────────────────────────────

func generate_layout(
		starting_room_name: String,
		max_rooms: int,
		filler_room_name: String) -> void:

	var rooms_placed := 1

	# Seed the BFS queue with every open door on the starting room.
	open_doors.assign(get_room_doors(starting_room_name, Vector3i(0, 0, 0)))
	open_doors.shuffle()

	while open_doors.size() > 0 and rooms_placed < max_rooms:
		var pending: Dictionary = open_doors.pop_front()
		var opposite_dir: String = OPPOSITE_DIR[pending["direction"]]

		# Collect every room that has at least one door on the required face.
		var candidates: Array[String] = get_rooms_with_door(opposite_dir)
		candidates.erase(starting_room_name)   # keep the entrance unique
		candidates.shuffle()

		# Demote the filler to the very end — it is a last resort only.
		if candidates.has(filler_room_name):
			candidates.erase(filler_room_name)
			candidates.append(filler_room_name)

		if _try_place_from_candidates(pending, candidates, opposite_dir):
			rooms_placed += 1

	if rooms_placed < max_rooms:
		push_warning("Layout finished with %d / %d rooms — some doors had no valid fit."
				% [rooms_placed, max_rooms])


## Tries each candidate in order; places the first one that fits without overlap.
## Returns true if a room was placed.
func _try_place_from_candidates(
		pending: Dictionary,
		candidates: Array[String],
		opposite_dir: String) -> bool:

	for candidate_name: String in candidates:
		var candidate_room: Dictionary = room_database[candidate_name]

		for door_tile_raw in candidate_room["doors"][opposite_dir]:
			var door_tile := int(door_tile_raw)
			var new_origin := _compute_new_room_origin(pending, candidate_room, door_tile)

			if _can_place_room(candidate_room, new_origin):
				add_room_to_dic(candidate_name, new_origin)

				# Queue every open door of the new room except the one we just used.
				for door: Dictionary in get_room_doors(candidate_name, new_origin):
					if not (door["direction"] == opposite_dir and door["door_tile"] == door_tile):
						open_doors.append(door)

				return true

	return false


# ── Geometry ──────────────────────────────────────────────────────────────────
#
#   Coordinate convention
#   ─────────────────────
#   north = −Z   south = +Z   east = +X   west = −X
#
#   Door-index meanings
#   ───────────────────
#   north / south doors: index is the X offset from the room origin (0 … width−1)
#   east  / west  doors: index is the Z offset from the room origin (0 … length−1)
#
#   A room at tile-origin (ox, oz) with length L, width W occupies:
#     north wall  z = oz          (local z = 0)
#     south wall  z = oz + L − 1 (local z = L − 1)
#     west wall   x = ox          (local x = 0)
#     east wall   x = ox + W − 1 (local x = W − 1)

func _compute_new_room_origin(
		pending: Dictionary,
		candidate_room: Dictionary,
		candidate_door_tile: int) -> Vector3i:

	var p_origin: Vector3i = pending["origin"]
	var p_room: Dictionary = room_database[pending["room_name"]]
	var i: int = pending["door_tile"]   # wall-offset on the parent side
	var j: int = candidate_door_tile    # wall-offset on the candidate side

	match pending["direction"]:
		"north":
			# Candidate's south wall must touch parent's north wall.
			# parent north tile row: z = p_origin.z
			# candidate south tile row: new_oz + candidate_length − 1 = p_origin.z − 1
			return Vector3i(p_origin.x + i - j, 0,
					p_origin.z - int(candidate_room["length"]))
		"south":
			# Candidate's north wall must touch parent's south wall.
			# parent south tile row: z = p_origin.z + parent_length − 1
			# candidate north tile row: new_oz = p_origin.z + parent_length
			return Vector3i(p_origin.x + i - j, 0,
					p_origin.z + int(p_room["length"]))
		"east":
			# Candidate's west wall must touch parent's east wall.
			# parent east column: x = p_origin.x + parent_width − 1
			# candidate west column: new_ox = p_origin.x + parent_width
			return Vector3i(p_origin.x + int(p_room["width"]), 0,
					p_origin.z + i - j)
		"west":
			# Candidate's east wall must touch parent's west wall.
			# parent west column: x = p_origin.x
			# candidate east column: new_ox + candidate_width − 1 = p_origin.x − 1
			return Vector3i(p_origin.x - int(candidate_room["width"]), 0,
					p_origin.z + i - j)

	return p_origin  # unreachable


## Returns true only if every tile the room would occupy is currently free.
func _can_place_room(room_data: Dictionary, origin: Vector3i) -> bool:
	for tile in room_data["occupied_tiles"]:
		if grid.has(Vector3i(origin.x + int(tile[0]), 0, origin.z + int(tile[1]))):
			return false
	return true


## Returns all open doors of `room_name` placed at `origin` as dictionaries
## ready for the BFS queue.
func get_room_doors(room_name: String, origin: Vector3i) -> Array[Dictionary]:
	var room: Dictionary = room_database[room_name]
	var result: Array[Dictionary] = []
	for dir: String in ["north", "south", "east", "west"]:
		for door_tile_raw in room["doors"][dir]:
			result.append({
				"origin":    origin,
				"room_name": room_name,
				"direction": dir,
				"door_tile": int(door_tile_raw),
			})
	return result


## All room names whose door data includes at least one door facing `direction`.
func get_rooms_with_door(direction: String) -> Array[String]:
	var result: Array[String] = []
	for room_name: String in room_database:
		if room_database[room_name]["doors"][direction].size() > 0:
			result.append(room_name)
	return result


# ── Spawning ──────────────────────────────────────────────────────────────────

func spawn_rooms() -> void:
	var spawned_passages: Dictionary = {}  # deduplicates door instances

	for room: Array in rooms:
		var scene_path: String    = room[0]
		var tile_origin: Vector3i = room[1]
		var room_name: String     = room[2]

		var room_node: Node3D = load(scene_path).instantiate()
		get_parent().add_child(room_node)

		# Convert tile coordinates to world-space units.
		room_node.global_position = Vector3(
				tile_origin.x * ROOM_SIZE, 0.0, tile_origin.z * ROOM_SIZE)

		# Apply the visual rotation stored in the database (degrees).
		var rotation_deg := float(room_database[room_name].get("rotation", 0))
		if rotation_deg != 0.0:
			room_node.rotate_y(deg_to_rad(rotation_deg))

		_spawn_room_doors(room_node, room_name, tile_origin, spawned_passages)


func _spawn_room_doors(
		room_node: Node3D,
		room_name: String,
		tile_origin: Vector3i,
		spawned_passages: Dictionary) -> void:

	var room: Dictionary = room_database[room_name]

	for dir: String in ["north", "south", "east", "west"]:
		for door_tile_raw in room["doors"][dir]:
			var door_tile := int(door_tile_raw)

			# Only open a door where the grid shows a room on the other side.
			# Anything else is a dead-end wall: leave it solid and the
			# doorframe hidden, exactly as the room scene starts out.
			var adjacent: Vector3i = _adjacent_tile(tile_origin, room, dir, door_tile)
			if not grid.has(adjacent):
				print("hallo")
				continue

			# Reveal THIS room's own doorframe and remove its own wall piece.
			# This happens independently for every connected room, since the
			# Walls/Doors nodes are local to each room's scene.
			var door_info: Dictionary = _get_door_info(room_node, dir, door_tile)
			if not door_info.is_empty():
				set_door_visible(door_info, true)
				disable_wall_at_door(door_info)

			# The interactable door object itself sits in the gap between two
			# rooms, so only spawn one per passage (deduplicated both ways).
			var face: Vector3i = _face_tile(tile_origin, room, dir, door_tile)
			var key: String    = _passage_key(face, adjacent)
			if spawned_passages.has(key):
				continue
			spawned_passages[key] = true

			var interactable: Node3D = door_scene.instantiate()
			get_parent().add_child(interactable)
			interactable.global_position = _door_world_position(tile_origin, room, dir, door_tile)
			interactable.rotation.y = _door_rotation(dir)
			available_doors.append(interactable)


## Looks up the doorframe node for a given direction/index inside a room
## scene, e.g. direction "north", door_tile 0 -> "Doors/DoorNorth0".
## Returns {} if the room scene doesn't have that node.
func _get_door_info(room_node: Node3D, direction: String, door_tile: int) -> Dictionary:
	var suffix: String   = direction.capitalize() + str(door_tile)
	var door_name: String = "Door" + suffix

	var doors_node: Node = room_node.get_node_or_null("Doors")
	if doors_node == null:
		return {}

	var door_node: Node = doors_node.get_node_or_null(door_name)
	if door_node == null:
		return {}

	return {
		"node": door_node,
		"room": room_node,
		"name": door_name,
	}


## Set the visibility of a door's frame node.
func set_door_visible(door_info: Dictionary, door_visible: bool) -> void:
	if not door_info.has("node"):
		return

	var door_node: Node = door_info["node"]
	if door_node:
		door_node.visible = door_visible


## Remove the wall segment that corresponds to an open door.
func disable_wall_at_door(door_info: Dictionary) -> void:
	print(door_info)
	if not door_info.has("node") or not door_info.has("room"):
		return

	var room_node: Node = door_info["room"]
	var door_name: String = door_info["name"]

	# "DoorNorth0" -> "WallNorth0"
	var wall_name: String = door_name.replace("Door", "Wall")

	var walls_node: Node = room_node.get_node_or_null("Walls")
	if not walls_node:
		return

	var wall_node: Node = walls_node.get_node_or_null(wall_name)
	if wall_node:
		wall_node.queue_free()


## World tile inside this room that the door opening is on.
func _face_tile(
		tile_origin: Vector3i,
		room: Dictionary,
		dir: String,
		door_tile: int) -> Vector3i:
	match dir:
		"north": return Vector3i(tile_origin.x + door_tile, 0, tile_origin.z)
		"south": return Vector3i(tile_origin.x + door_tile, 0,
				tile_origin.z + int(room["length"]) - 1)
		"east":  return Vector3i(tile_origin.x + int(room["width"]) - 1, 0,
				tile_origin.z + door_tile)
		"west":  return Vector3i(tile_origin.x, 0, tile_origin.z + door_tile)
	return tile_origin


## World tile immediately outside this room's wall — i.e. in the next room.
func _adjacent_tile(
		tile_origin: Vector3i,
		room: Dictionary,
		dir: String,
		door_tile: int) -> Vector3i:
	match dir:
		"north": return Vector3i(tile_origin.x + door_tile, 0, tile_origin.z - 1)
		"south": return Vector3i(tile_origin.x + door_tile, 0,
				tile_origin.z + int(room["length"]))
		"east":  return Vector3i(tile_origin.x + int(room["width"]), 0,
				tile_origin.z + door_tile)
		"west":  return Vector3i(tile_origin.x - 1, 0, tile_origin.z + door_tile)
	return tile_origin


## Canonical key for the wall gap between two adjacent tiles.
## Always produces the same string regardless of argument order.
func _passage_key(a: Vector3i, b: Vector3i) -> String:
	if a.x < b.x or (a.x == b.x and a.z < b.z):
		return "%d,%d|%d,%d" % [a.x, a.z, b.x, b.z]
	return "%d,%d|%d,%d" % [b.x, b.z, a.x, a.z]


## Centre of the wall gap in world space. Y = 0; adjust to match your door scene.
func _door_world_position(
		tile_origin: Vector3i,
		room: Dictionary,
		dir: String,
		door_tile: int) -> Vector3:
	var half := ROOM_SIZE * 0.5
	match dir:
		"north":
			return Vector3(
					(tile_origin.x + door_tile) * ROOM_SIZE + half, 0.0,
					 tile_origin.z * ROOM_SIZE)
		"south":
			return Vector3(
					(tile_origin.x + door_tile) * ROOM_SIZE + half, 0.0,
					(tile_origin.z + int(room["length"])) * ROOM_SIZE)
		"east":
			return Vector3(
					(tile_origin.x + int(room["width"])) * ROOM_SIZE, 0.0,
					(tile_origin.z + door_tile) * ROOM_SIZE + half)
		"west":
			return Vector3(
					 tile_origin.x * ROOM_SIZE, 0.0,
					(tile_origin.z + door_tile) * ROOM_SIZE + half)
	return Vector3.ZERO


## N/S doors face along Z (no rotation); E/W doors face along X (90°).
func _door_rotation(dir: String) -> float:
	return PI * 0.5 if (dir == "east" or dir == "west") else 0.0
