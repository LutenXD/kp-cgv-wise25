extends Node3D

@onready var info_panel = $UI/InfoPanel
@onready var info_title = $UI/InfoPanel/MarginContainer/VBoxContainer/Title
@onready var info_text = $UI/InfoPanel/MarginContainer/VBoxContainer/ScrollContainer/InfoText
@onready var player = $player
@onready var camera = $player/Camera3D

@onready var sphere1 = $InteractiveSpheres/Sphere1
@onready var sphere2 = $InteractiveSpheres/Sphere2
@onready var sphere3 = $InteractiveSpheres/Sphere3

var lore_manager: LoreManager
var selected_items: Array = []
var current_sphere = null
var all_lore_items: Array = []

const RAY_LENGTH = 100.0

func _ready():
	info_panel.hide()
	
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
		
		# Restore sphere assignments
		if state.has("sphere_assignments"):
			var sphere_data = state["sphere_assignments"]
			if sphere1 and sphere_data.has("sphere1"):
				sphere1.set_lore_items(sphere_data["sphere1"])
			if sphere2 and sphere_data.has("sphere2"):
				sphere2.set_lore_items(sphere_data["sphere2"])
			if sphere3 and sphere_data.has("sphere3"):
				sphere3.set_lore_items(sphere_data["sphere3"])
		
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
	
	# Distribute lore to spheres
	var sphere_data = lore_manager.distribute_lore_to_spheres(selected_lore)
	
	# Store sphere assignments for saving
	var settings = get_game_settings()
	if settings:
		settings.save_game_state(player.global_position, selected_lore, sphere_data, [])
	
	# Assign lore to each sphere
	if sphere1 and sphere_data.has("sphere1"):
		sphere1.set_lore_items(sphere_data["sphere1"])
		print("Sphere 1 assigned ", sphere_data["sphere1"].size(), " lore items")
	
	if sphere2 and sphere_data.has("sphere2"):
		sphere2.set_lore_items(sphere_data["sphere2"])
		print("Sphere 2 assigned ", sphere_data["sphere2"].size(), " lore items")
	
	if sphere3 and sphere_data.has("sphere3"):
		sphere3.set_lore_items(sphere_data["sphere3"])
		print("Sphere 3 assigned ", sphere_data["sphere3"].size(), " lore items")
	
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
	if event.is_action_pressed("ui_cancel"):
		return_to_main_menu()
	
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
		var sphere_data = {
			"sphere1": sphere1.get_lore_items() if sphere1 else [],
			"sphere2": sphere2.get_lore_items() if sphere2 else [],
			"sphere3": sphere3.get_lore_items() if sphere3 else []
		}
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
