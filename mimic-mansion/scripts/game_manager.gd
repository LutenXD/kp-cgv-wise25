extends Node3D

@onready var info_panel = $UI/InfoPanel
@onready var info_title = $UI/InfoPanel/MarginContainer/VBoxContainer/Title
@onready var info_text = $UI/InfoPanel/MarginContainer/VBoxContainer/InfoText
@onready var player = $player
@onready var camera = $player/Camera3D

const RAY_LENGTH = 100.0

func _ready():
	info_panel.hide()

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
