extends CanvasLayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Visualize rooms after layout is generated
	call_deferred("visualize_rooms")

func visualize_rooms():
	"""Create visual markers for room tiles and doorways"""
	var layout_generator = get_parent().get_node("RoomLayout")
	if not layout_generator:
		return
	
	# Clear old markers
	for child in get_parent().get_children():
		if child.name.begins_with("TileMarker") or child.name.begins_with("DoorMarker"):
			child.queue_free()
	
	# Visualize each room's tiles
	for room_data in layout_generator.room_instances:
		var template = room_data["template"]
		
		# Draw room bounds
		for x in range(template["tiles_x"]):
			for z in range(template["tiles_z"]):
				var tile_marker = MeshInstance3D.new()
				tile_marker.name = "TileMarker_" + room_data["name"]
				
				var box = BoxMesh.new()
				box.size = Vector3(layout_generator.TILE_SIZE * 0.9, 0.1, layout_generator.TILE_SIZE * 0.9)
				
				var material = StandardMaterial3D.new()
				material.albedo_color = Color(0.3, 0.3, 0.8, 0.5)
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				
				tile_marker.mesh = box
				tile_marker.material_override = material
				
				var world_x = (room_data["tile_x"] + x) * layout_generator.TILE_SIZE + layout_generator.TILE_SIZE / 2
				var world_z = (room_data["tile_z"] + z) * layout_generator.TILE_SIZE + layout_generator.TILE_SIZE / 2
				tile_marker.position = Vector3(world_x, 0.5, world_z)
				
				get_parent().add_child(tile_marker)
		
		# Visualize doorways
		for doorway in template["doorways"]:
			var door_pos = calculate_doorway_world_position(room_data, doorway, layout_generator.TILE_SIZE)
			
			var door_marker = MeshInstance3D.new()
			door_marker.name = "DoorMarker_" + room_data["name"]
			
			var sphere = SphereMesh.new()
			sphere.radius = 0.8
			
			var material = StandardMaterial3D.new()
			# Green if connected, yellow if not
			if doorway in room_data["connected_doors"]:
				material.albedo_color = Color(0, 1, 0, 1)
			else:
				material.albedo_color = Color(1, 1, 0, 1)
			
			door_marker.mesh = sphere
			door_marker.material_override = material
			door_marker.position = door_pos
			
			get_parent().add_child(door_marker)

func calculate_doorway_world_position(room_data: Dictionary, doorway: Dictionary, tile_size: float) -> Vector3:
	"""Calculate world position of a doorway"""
	var room_x = room_data["tile_x"] * tile_size
	var room_z = room_data["tile_z"] * tile_size
	var template = room_data["template"]
	
	var pos = Vector3.ZERO
	match doorway["side"]:
		"north":
			pos = Vector3(room_x + doorway["tile_offset"] * tile_size, 1, room_z)
		"south":
			pos = Vector3(room_x + doorway["tile_offset"] * tile_size, 1, room_z + template["tiles_z"] * tile_size)
		"east":
			pos = Vector3(room_x + template["tiles_x"] * tile_size, 1, room_z + doorway["tile_offset"] * tile_size)
		"west":
			pos = Vector3(room_x, 1, room_z + doorway["tile_offset"] * tile_size)
	
	return pos

func _on_regenerate_button_pressed():
	# Get the room layout generator and regenerate
	var layout_generator = get_parent().get_node("RoomLayout")
	if layout_generator:
		layout_generator.regenerate_layout()
		print("Room layout regenerated!")
		# Visualize new layout
		call_deferred("visualize_rooms")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/options_menu.tscn")
