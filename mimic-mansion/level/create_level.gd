@tool
extends Node3D


@export_tool_button("Generate Layout", "Callable") var generate_action = generate_level
@export var rooms: Array[PackedScene]
@export var max_rooms: int = 5
@export var room_propability: float = 0.5
@export var allow_room_reuse = true

var room_index: int = 0
#var open_doors: Array[RoomConnection]
var rnd: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var room_container: Node = $RoomContainer


func _ready() -> void:
	generate()


func get_connection_markers_from_scene_root(root: Node3D) -> Array[RoomConnection]:
	var connections: Array[RoomConnection] = []
	for child in root.get_node_or_null("Connections").get_children():
		connections.append(child)
	return connections


func compute_room_transform_to_align_door(target_door_global: Transform3D, candidate_door_local: Transform3D) -> Transform3D:
	# rotate 180 degrees around Y to make doors face each other
	var flip = Transform3D(Basis().rotated(Vector3.UP, PI), Vector3.ZERO)
	var desired_door_global = target_door_global * flip
	return desired_door_global * candidate_door_local.affine_inverse()


func compute_local_aabb(node: Node3D) -> AABB:
	# conservative: merge AABBs of MeshInstance3D and CollisionShapes
	var total_aabb := AABB(Vector3.ZERO, Vector3.ZERO)
	var first = true
	for n in node.get_children(true):
		if n is MeshInstance3D:
			var a = n.get_aabb()
			# transform by node's local transform relative to root:
			#var local_xform = n.get_global_transform().affine_inverse() # not used; easier to convert by transforming corners
			# to be conservative and simple: transform the mesh AABB into root space using global transforms
			var global_aabb = a.transformed(n.get_global_transform())
			if first:
				total_aabb = global_aabb
				first = false
			else:
				total_aabb = total_aabb.merge(global_aabb)
		elif n is CollisionShape3D:
			var shape = n.shape
			if shape:
				var a = shape.get_aabb()
				var global_aabb = a.transformed(n.get_global_transform())
				if first:
					total_aabb = global_aabb
					first = false
				else:
					total_aabb = total_aabb.merge(global_aabb)
	# if no geometry found, return a tiny box
	if first:
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1,1,1))
	return total_aabb


func overlaps_existing(transformed_aabb: AABB, placed_aabbs: Array[AABB]) -> bool:
	for a in placed_aabbs:
		if a.intersects(transformed_aabb):
			return true
	return false


func generate_level() -> void:
	rnd.randomize()
	for room in room_container.get_children():
		room.queue_free()
	
	if rooms.is_empty():
		push_error("room_scenes empty")
		return

	var placed_rooms: Array[Node3D] = []
	var open_doors := [] # each element: { "room": Node3D, "marker_path": NodePath, "global_transform": Transform3D }

	# place seed room
	var seed_idx = rnd.randi_range(0, rooms.size() - 1)
	var seed_inst := rooms[seed_idx].instantiate() as Node3D
	add_child(seed_inst)
	seed_inst.transform = Transform3D() # placed at origin
	placed_rooms.append(seed_inst)

	for d in get_connection_markers_from_scene_root(seed_inst):
		open_doors.append({ "room": seed_inst, "marker_path": d.get_path(), "global_transform": d.global_transform })

	# available prefab indices if not reusing
	var available := []
	for i in rooms.size():
		available.append(i)

	# loop until filled or out of open doors
	while placed_rooms.size() < max_rooms and open_doors.size() > 0:
		var oi = rnd.randi_range(0, open_doors.size() - 1)
		var open = open_doors[oi]
		var target_door_global: Transform3D = open["global_transform"]

		var placed_this_round := false

		# shuffle prefab order for variety
		var prefab_order := []
		for i in rooms.size():
			prefab_order.append(i)
		prefab_order.shuffle()

		for prefab_idx in prefab_order:
			if not allow_room_reuse and prefab_idx not in available:
				continue

			var prefab := rooms[prefab_idx]
			var candidate := prefab.instantiate() as Node3D

			var candidate_doors := get_connection_markers_from_scene_root(candidate)
			candidate_doors.shuffle()

			for cand_marker in candidate_doors:
				# compute transform aligning candidate door to target door
				var candidate_local = cand_marker.transform
				var room_xform = compute_room_transform_to_align_door(target_door_global, candidate_local)
				candidate.transform = room_xform

				# place permanently (no overlap checks)
				add_child(candidate)
				placed_rooms.append(candidate)

				# remove the open door we just filled
				open_doors.remove_at(oi)

				# add all other doors from candidate as open doors
				for d in get_connection_markers_from_scene_root(candidate):
					# skip the marker we used (compare by name & local transform)
					if d.name == cand_marker.name and is_equal_approx(d.transform.origin.distance_to(cand_marker.transform.origin), 0.0):
						continue
					open_doors.append({ "room": candidate, "marker_path": d.get_path(), "global_transform": d.global_transform })

				if not allow_room_reuse:
					available.erase(prefab_idx)

				placed_this_round = true
				break  # stop trying more doors in this prefab

			if placed_this_round:
				break
			else:
				# not placed: free candidate since it wasn't added to scene (we used add_child only on success)
				candidate.queue_free()

		if not placed_this_round:
			# cannot place any prefab to this open door: seal it (optional) and drop from list
			#seal_dead_end_at(target_door_global)
			open_doors.remove_at(oi)
			# continue loop

	# finished
	print("Rooms placed:", placed_rooms.size())

func generate() -> void:
	print("------room generation started------")
	rnd.randomize()
	room_index = 0
	for room in room_container.get_children():
		room.queue_free()
	
	#open_doors.clear()
	for connection: RoomConnection in $Corridor.get_node_or_null("Connections").get_children():
		connection.connected = false
		#open_doors.append(connection)
	
	place_room_on_connections($Corridor)
	
	while room_index < max_rooms:
		print("------------------------------")
		for room: Node3D in room_container.get_children():
			place_room_on_connections(room)


func place_room_on_connections(room: Node3D) -> void:
	for connection: RoomConnection in room.get_node_or_null("Connections").get_children():
		if randf() > room_propability:
			continue
		
		if connection.connected:
			print("connected")
			continue
		
		if room_index >= max_rooms:
			return
		
		place_rand_room(connection)


func place_rand_room(root_connection: RoomConnection) -> bool:
	if root_connection.connected:
		print("hää?")
		return false
	var new_room: Node3D = rooms[randi() % rooms.size()].instantiate()
	var connections: Array = new_room.get_node_or_null("Connections").get_children()
	
	var target_connection: RoomConnection = connections[randi() % connections.size()]
	var i: int = 0
	while target_connection.connected:
		target_connection = connections[randi() % connections.size()]
		i += 1
		if i >= 10: return false
	
	
	var root_transform: Transform3D = root_connection.global_transform
	var target_local: Transform3D = target_connection.transform
	
	new_room.global_transform = root_transform * Transform3D.IDENTITY.rotated(Vector3.UP, PI) * target_local.affine_inverse()
	
	root_connection.connected = true
	target_connection.connected = true
	
	room_index += 1
	
	printt("spawn room: ", room_index)
	
	new_room.get_node_or_null("Label3D").text = "Room " + str(room_index)
	
	room_container.add_child(new_room)
	return true
