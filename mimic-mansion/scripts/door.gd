extends Area3D

signal door_opened()

@export var is_locked: bool = false
@export var target_room: String = ""

var is_player_nearby: bool = false
var is_open: bool = false
var door_mesh: MeshInstance3D
var original_rotation: float = 0.0
var target_rotation: float = 0.0
var rotation_speed: float = 3.0

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	door_mesh = $DoorFrame

func _on_body_entered(body):
	if body.name == "player" and not is_locked:
		is_player_nearby = true
		open_door()

func _on_body_exited(body):
	if body.name == "player":
		is_player_nearby = false
		# Close door after player leaves
		await get_tree().create_timer(1.0).timeout
		if not is_player_nearby:
			close_door()

func _process(delta):
	if door_mesh:
		# Smoothly rotate door
		door_mesh.rotation.y = lerp_angle(door_mesh.rotation.y, target_rotation, rotation_speed * delta)

func open_door():
	if not is_open:
		is_open = true
		target_rotation = -PI / 2  # Swing 90 degrees
		door_opened.emit()
		print("Door opened to: ", target_room)

func close_door():
	if is_open:
		is_open = false
		target_rotation = 0.0
