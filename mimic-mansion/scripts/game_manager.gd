extends Node3D

@onready var info_panel = $UI/InfoPanel
@onready var info_title = $UI/InfoPanel/MarginContainer/VBoxContainer/Title
@onready var info_text = $UI/InfoPanel/MarginContainer/VBoxContainer/InfoText
@onready var player = $player
@onready var camera = $player/Camera3D

@onready var sphere1 = $InteractiveSpheres/Sphere1
@onready var sphere2 = $InteractiveSpheres/Sphere2
@onready var sphere3 = $InteractiveSpheres/Sphere3

var lore_manager: LoreManager

const RAY_LENGTH = 100.0

func _ready():
	info_panel.hide()
	initialize_lore_system()

func initialize_lore_system():
	# Create and initialize lore manager
	lore_manager = LoreManager.new()
	add_child(lore_manager)
	
	# Wait a frame for lore to load
	await get_tree().process_frame
	
	# Select 10 random lore items
	var selected_lore = lore_manager.select_random_lore_items(10)
	
	if selected_lore.is_empty():
		push_error("Failed to select lore items")
		return
	
	# Distribute lore to spheres
	var sphere_data = lore_manager.distribute_lore_to_spheres(selected_lore)
	
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
			show_info(collider.get_info())

func show_info(info: Dictionary):
	info_title.text = info.name
	info_text.text = info.text
	info_panel.show()
	
	# Auto-hide after 5 seconds
	await get_tree().create_timer(5.0).timeout
	info_panel.hide()

func _process(_delta):
	# Press E or click to interact
	if Input.is_action_just_pressed("ui_accept"):
		if info_panel.visible:
			info_panel.hide()
