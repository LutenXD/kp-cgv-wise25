extends Node3D

@onready var info_panel = $UI/InfoPanel
@onready var info_title = $UI/InfoPanel/MarginContainer/VBoxContainer/Title
@onready var info_text = $UI/InfoPanel/MarginContainer/VBoxContainer/ScrollContainer/InfoText
@onready var player = $player
@onready var camera = $player/Camera3D

var lore_manager: LoreManager
var selected_items: Array = []
var current_sphere = null
var all_lore_items: Array = []
var spawned_mimics: Array = []
var spawned_rooms: Array = []

const RAY_LENGTH = 100.0
const ROOM_SIZE = 10.0  # Standard room size for positioning
const HALLWAY_COUNT = 3  # Number of hallway instances to create

# Define unique room scene paths (appear only once)
const UNIQUE_ROOMS = [
	"res://assets/rooms/art_gallery.tscn",
	"res://assets/rooms/attic.tscn", 
	"res://assets/rooms/basement_dungeon.tscn",
	"res://assets/rooms/bathroom.tscn",
	"res://assets/rooms/chapel_crypt.tscn",
	"res://assets/rooms/children_nursery.tscn",
	"res://assets/rooms/conservatory_greenhouse.tscn",
	"res://assets/rooms/courtyard_garden.tscn",
	"res://assets/rooms/dining_room.tscn",
	"res://assets/rooms/grand_foyer.tscn",
	"res://assets/rooms/grand_hall_ballroom.tscn",
	"res://assets/rooms/kitchen_pantry.tscn",
	"res://assets/rooms/laundry_room.tscn",
	"res://assets/rooms/library.tscn",
	"res://assets/rooms/master_bedroom.tscn",
	"res://assets/rooms/music_room.tscn",
	"res://assets/rooms/secret_study.tscn",
	"res://assets/rooms/servants_quarters.tscn",
	"res://assets/rooms/wine_cellar.tscn"
]

# Define hallway scene paths (can appear multiple times)
const HALLWAY_ROOMS = [
	"res://assets/rooms/hallway_junction_1.tscn",
	"res://assets/rooms/hallway_junction_2.tscn",
	"res://assets/rooms/hallway_straight.tscn"
]

# Define mimic spawn locations (relative to each room center)
const MIMIC_SPAWN_POSITIONS = [
	Vector3(3, 1, 0),
	Vector3(-3, 1, 0),
	Vector3(0, 1, 3),
	Vector3(0, 1, -3),
	Vector3(2, 1, 2),
	Vector3(-2, 1, -2),
]

func _ready():
	info_panel.hide()
	
	# Remove the default room from the scene if it exists
	var default_room = get_node_or_null("Room")
	if default_room:
		default_room.queue_free()
	
	# Spawn rooms in a grid layout
	spawn_rooms()
	
	# Check if we're continuing a game
	var settings = get_game_settings()
	if settings and settings.is_game_in_progress():
		load_saved_state()
	else:
		initialize_lore_system()

func get_game_settings():
	if has_node("/root/GameSettings"):
		return get_node("/root/GameSettings")
	return null

func spawn_rooms():
	"""Spawn all rooms in a grid layout next to each other"""
	print("Spawning rooms in grid layout...")
	
	var rooms_parent = Node3D.new()
	rooms_parent.name = "Rooms"
	add_child(rooms_parent)
	
	# Combine unique rooms and multiple hallway instances
	var all_room_paths = UNIQUE_ROOMS.duplicate()
	
	# Add multiple instances of hallways
	for i in range(HALLWAY_COUNT):
		for hallway_path in HALLWAY_ROOMS:
			all_room_paths.append(hallway_path)
	
	# Calculate grid dimensions (try to make roughly square)
	var total_rooms = all_room_paths.size()
	var grid_size = ceil(sqrt(total_rooms))
	
	print("Total rooms to spawn: ", total_rooms)
	print("Grid size: ", grid_size, "x", grid_size)
	
	# Spawn rooms in grid
	var room_index = 0
	for y in range(grid_size):
		for x in range(grid_size):
			if room_index >= all_room_paths.size():
				break
			
			var room_path = all_room_paths[room_index]
			var room_scene = load(room_path)
			
			if room_scene:
				var room_instance = room_scene.instantiate()
				
				# Calculate world position (center rooms around origin)
				var offset_x = (x - grid_size / 2.0) * ROOM_SIZE
				var offset_z = (y - grid_size / 2.0) * ROOM_SIZE
				room_instance.global_position = Vector3(offset_x, 0, offset_z)
				
				# Give the room a unique name
				room_instance.name = "Room_" + str(room_index) + "_" + room_path.get_file().get_basename()
				
				rooms_parent.add_child(room_instance)
				spawned_rooms.append(room_instance)
				
				print("Spawned room: ", room_instance.name, " at position: ", room_instance.global_position)
			else:
				print("Failed to load room: ", room_path)
			
			room_index += 1
	
	print("Total rooms spawned: ", spawned_rooms.size())
	
	# Position player in the center room
	if player:
		player.global_position = Vector3(0, 1, 0)
		print("Player positioned at center: ", player.global_position)

func spawn_mimics(sphere_data: Dictionary):
	# Create InteractiveSpheres parent node if it doesn't exist
	var spheres_parent = get_node_or_null("InteractiveSpheres")
	if not spheres_parent:
		spheres_parent = Node3D.new()
		spheres_parent.name = "InteractiveSpheres"
		add_child(spheres_parent)
	
	# Get mimic count from settings
	var settings = get_game_settings()
	var count = settings.get_mimic_count() if settings else 3
	
	# Calculate available positions across all rooms
	var available_positions = []
	for room in spawned_rooms:
		var room_center = room.global_position
		for local_pos in MIMIC_SPAWN_POSITIONS:
			var world_pos = room_center + local_pos
			available_positions.append(world_pos)
	
	# Don't exceed available positions
	count = min(count, available_positions.size())
	
	# Clear existing mimics
	spawned_mimics.clear()
	
	# Randomly select positions
	available_positions.shuffle()
	
	# Spawn mimics at selected positions
	for i in range(count):
		var position = available_positions[i]
		var mimic_id = "mimic" + str(i + 1)
		var mimic = create_mimic("Mimic_" + str(i + 1), mimic_id, position)
		
		# Assign lore items if available
		if sphere_data.has(mimic_id):
			mimic.set_lore_items(sphere_data[mimic_id])
			print("Mimic ", i + 1, " assigned ", sphere_data[mimic_id].size(), " lore items")
		
		spheres_parent.add_child(mimic)
		spawned_mimics.append(mimic)
		print("Spawned mimic at position: ", position)
	
	print("Total mimics spawned: ", count)
	
	# Generate statements about other mimics and add them to each mimic
	generate_mimic_statements()

func generate_mimic_statements():
	"""Generate statements about whether other mimics are honest or liars"""
	if spawned_mimics.size() < 2:
		return  # Need at least 2 mimics to make statements about each other
	
	var settings = get_game_settings()
	var true_ratio = settings.get_true_ratio() if settings else 0.2
	
	# Track all generated statements: key = statement text, value = {is_true, about_mimic, mimics_with_statement}
	var all_statements = {}
	
	# First pass: generate statements and track them
	var mimic_statements = {}  # mimic -> list of statement items
	
	for mimic in spawned_mimics:
		var new_statements = []
		mimic_statements[mimic] = new_statements
		
		# Generate statements about each other mimic
		for other_mimic in spawned_mimics:
			if other_mimic == mimic:
				continue  # Don't make statements about yourself
			
			# Determine if this statement will be true or false
			var statement_is_true = randf() < true_ratio
			
			# Get the actual honesty state of the other mimic
			var other_is_honest = (other_mimic.honesty == other_mimic.Honesty.HONEST)
			var other_is_liar = (other_mimic.honesty == other_mimic.Honesty.LIAR)
			var other_is_partial = (other_mimic.honesty == other_mimic.Honesty.PARTIAL_LIAR)
			
			# Create statement based on whether it should be true or false
			var statement_text = ""
			var category = "Mimic Statement"
			
			if statement_is_true:
				# Make a true statement about the other mimic
				if other_is_honest:
					statement_text = other_mimic.sphere_name + " always tells the truth."
				elif other_is_liar:
					statement_text = other_mimic.sphere_name + " always lies."
				else:  # partial liar
					statement_text = other_mimic.sphere_name + " tells both truths and lies."
			else:
				# Make a false statement about the other mimic
				if other_is_honest:
					statement_text = other_mimic.sphere_name + " is a complete liar."
				elif other_is_liar:
					statement_text = other_mimic.sphere_name + " is completely honest."
				else:  # partial liar
					var false_type = randi() % 2
					if false_type == 0:
						statement_text = other_mimic.sphere_name + " always tells the truth."
					else:
						statement_text = other_mimic.sphere_name + " never tells the truth."
			
			# Create the statement item
			var statement_item = {
				"category": category,
				"description": statement_text,
				"is_true": statement_is_true,
				"about_mimic": other_mimic
			}
			
			new_statements.append(statement_item)
			
			# Track this statement
			if not all_statements.has(statement_text):
				all_statements[statement_text] = {
					"is_true": statement_is_true,
					"about_mimic": other_mimic,
					"mimics_with_statement": []
				}
			all_statements[statement_text]["mimics_with_statement"].append(mimic)
	
	# Second pass: ensure true statements appear in at least one other mimic
	for statement_text in all_statements.keys():
		var statement_data = all_statements[statement_text]
		
		if statement_data["is_true"] and statement_data["mimics_with_statement"].size() == 1:
			# This true statement only appears in one mimic, add it to another
			var original_mimic = statement_data["mimics_with_statement"][0]
			var about_mimic = statement_data["about_mimic"]
			
			# Find another mimic that doesn't have this statement and isn't the subject
			var candidates = []
			for mimic in spawned_mimics:
				if mimic != original_mimic and mimic != about_mimic:
					candidates.append(mimic)
			
			if candidates.size() > 0:
				# Pick a random candidate to also have this statement
				var chosen_mimic = candidates[randi() % candidates.size()]
				var corroborating_item = {
					"category": "Mimic Statement",
					"description": statement_text,
					"is_true": true,
					"about_mimic": about_mimic
				}
				mimic_statements[chosen_mimic].append(corroborating_item)
				print("Added corroborating statement to ", chosen_mimic.sphere_name, ": ", statement_text)
	
	# Third pass: assign all statements to mimics
	for mimic in spawned_mimics:
		var existing_items = mimic.get_lore_items()
		var new_statements = mimic_statements[mimic]
		
		# Remove temporary "about_mimic" key before adding
		for item in new_statements:
			item.erase("about_mimic")
		
		var combined_items = existing_items + new_statements
		mimic.set_lore_items(combined_items)
		
		print(mimic.sphere_name, " now has ", combined_items.size(), " total items (", 
			  new_statements.size(), " mimic statements added)")

func create_mimic(mimic_name: String, mimic_id: String, position: Vector3) -> StaticBody3D:
	# Load the interactive_sphere script
	var sphere_script = load("res://scripts/interactive_sphere.gd")
	
	# Create the mimic sphere
	var mimic = StaticBody3D.new()
	mimic.name = mimic_name
	mimic.set_script(sphere_script)
	mimic.sphere_name = mimic_name
	mimic.sphere_id = mimic_id
	mimic.global_position = position
	
	# Create mesh
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	mesh_instance.mesh = sphere_mesh
	
	# Create material for the sphere
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.3, 0.3)  # Reddish color for mimics
	material.metallic = 0.5
	material.roughness = 0.3
	mesh_instance.set_surface_override_material(0, material)
	
	mimic.add_child(mesh_instance)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.5
	collision_shape.shape = sphere_shape
	mimic.add_child(collision_shape)
	
	return mimic

func load_saved_state():
	var settings = get_game_settings()
	if not settings:
		initialize_lore_system()
		return
	
	var state = settings.load_game_state()
	
	# Restore player position
	if player and state.has("player_position"):
		player.global_position = state["player_position"]
	
	# Restore lore system
	if state.has("selected_lore") and not state["selected_lore"].is_empty():
		all_lore_items = state["selected_lore"]
		
		# Restore sphere assignments by spawning mimics with saved data
		if state.has("sphere_assignments"):
			var sphere_data = state["sphere_assignments"]
			spawn_mimics(sphere_data)
		
		# Restore selected items
		if state.has("selected_items"):
			selected_items = state["selected_items"]
		
		print("Game state loaded - continuing from saved position")
	else:
		initialize_lore_system()

func initialize_lore_system():
	# Create and initialize lore manager
	lore_manager = LoreManager.new()
	add_child(lore_manager)
	
	# Wait a frame for lore to load
	await get_tree().process_frame
	
	# Select 10 random lore items
	var selected_lore = lore_manager.select_random_lore_items(10)
	all_lore_items = selected_lore
	
	if selected_lore.is_empty():
		push_error("Failed to select lore items")
		return
	
	# Print all selected items
	print("\n=== SELECTED LORE ITEMS ===")
	for i in range(selected_lore.size()):
		var item = selected_lore[i]
		print(str(i) + ". [" + item.get("category", "Unknown") + "] " + 
			  "(" + ("TRUE" if item.get("is_true", false) else "FALSE") + ") - " + 
			  item.get("description", "No description"))
	print("==========================\n")
	
	# Get mimic count and distribute lore accordingly
	var settings = get_game_settings()
	var mimic_count = settings.get_mimic_count() if settings else 3
	
	# Distribute lore items evenly across mimics
	var sphere_data = {}
	var items_per_mimic = selected_lore.size() / mimic_count
	var remainder = selected_lore.size() % mimic_count
	
	var item_index = 0
	for i in range(mimic_count):
		var mimic_id = "mimic" + str(i + 1)
		var count_for_this_mimic = int(items_per_mimic)
		if i < remainder:
			count_for_this_mimic += 1
		
		var mimic_items = []
		for j in range(count_for_this_mimic):
			if item_index < selected_lore.size():
				mimic_items.append(selected_lore[item_index])
				item_index += 1
		
		sphere_data[mimic_id] = mimic_items
	
	# Spawn mimics with assigned lore
	spawn_mimics(sphere_data)
	
	# Store sphere assignments for saving
	if settings:
		settings.save_game_state(player.global_position, selected_lore, sphere_data, [])
	
	print("Lore system initialized successfully")

func _input(event):
	if event.is_action_pressed("ui_select") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		# If panel is visible, hide it on click
		if info_panel.visible:
			info_panel.hide()
		else:
			check_raycast()

func check_raycast():
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_size() / 2
	
	var origin = camera.global_position
	var end = origin + camera.global_transform.basis.z * -RAY_LENGTH
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider.has_method("get_info"):
			current_sphere = collider
			show_info(collider.get_info())

func show_info(info: Dictionary):
	info_title.text = info.name
	info_text.text = info.text
	info_panel.show()
	print("\nViewing sphere: " + info.name)
	print("Press 1, 2, or 3 to select items from this sphere")
	print("Press M to assign selected items as mimics\n")

func _unhandled_input(event):
	# Press ESC to return to main menu
#	if event.is_action_pressed("ui_cancel"):
#		return_to_main_menu()
	
	# Press number keys (1-3) to select items from the current sphere
	if info_panel.visible and current_sphere:
		if event is InputEventKey and event.pressed and not event.echo:
			var key_code = event.keycode
			if key_code >= KEY_1 and key_code <= KEY_3:
				var item_index = key_code - KEY_1
				select_item(item_index)
	
	# Press M to mark selected items as mimics
	if event.is_action_pressed("ui_text_completion_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		assign_mimics()

func return_to_main_menu():
	# Save current game state
	var settings = get_game_settings()
	if settings and player:
		# Save all spawned mimic data
		var sphere_data = {}
		for mimic in spawned_mimics:
			if mimic:
				sphere_data[mimic.sphere_id] = mimic.get_lore_items()
		settings.save_game_state(player.global_position, all_lore_items, sphere_data, selected_items)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func select_item(index: int):
	if not current_sphere:
		return
	
	var items = current_sphere.get_lore_items()
	if index >= 0 and index < items.size():
		var item = items[index]
		
		# Toggle selection
		if selected_items.has(item):
			selected_items.erase(item)
			var desc1 = item.get("description", "No description")
			print("Deselected item: [" + item.get("category", "Unknown") + "] " + desc1.substr(0, 50) + "...")
		else:
			selected_items.append(item)
			var desc2 = item.get("description", "No description")
			print("Selected item: [" + item.get("category", "Unknown") + "] " + desc2.substr(0, 50) + "...")
		
		print("Total selected: " + str(selected_items.size()))

func assign_mimics():
	if selected_items.is_empty():
		print("No items selected to assign as mimics!")
		return
	
	print("\n=== ASSIGNING MIMICS ===")
	for item in selected_items:
		var is_true = item.get("is_true", false)
		var category = item.get("category", "Unknown")
		var desc_full = item.get("description", "No description")
		var desc = desc_full.substr(0, 50) + "..."
		
		if is_true:
			print("✓ CORRECT! [" + category + "] - This is TRUE (not a mimic)")
		else:
			print("✗ MIMIC FOUND! [" + category + "] - This is FALSE")
			print("  Description: " + desc)
	
	print("Total items marked: " + str(selected_items.size()))
	print("==========================\n")
