extends Node3D

# Tracks which room the player is currently in

@export var player_path: NodePath
@export var room_label_path: NodePath

var player: CharacterBody3D
var room_label: Label
var current_room: String = "Grand Foyer"
var room_areas: Dictionary = {}

func _ready():
	# Get player and label references
	if player_path:
		player = get_node(player_path)
	if room_label_path:
		room_label = get_node(room_label_path)
	
	# Wait a frame for rooms to be generated
	await get_tree().process_frame
	
	# Create area triggers for each room
	create_room_triggers()
	
	# Set initial room
	if room_label:
		room_label.text = format_room_name(current_room)

func create_room_triggers():
	"""Create invisible area triggers for each room to detect player entry"""
	var room_layout = get_parent().get_node("RoomLayout")
	if not room_layout:
		return
	
	# Get all room instances
	for child in room_layout.get_children():
		if child is Node3D and child.name in get_room_names():
			create_room_area(child)

func get_room_names() -> Array:
	return [
		"grand_foyer", "library", "dining_room",
		"kitchen_pantry", "laundry_room", "music_room", "art_gallery",
		"conservatory", "courtyard", "master_bedroom", "bathroom",
		"children_nursery", "servants_quarters", "secret_study",
		"attic", "basement_dungeon", "wine_cellar", "chapel_crypt"
	]

func create_room_area(room_node: Node3D):
	"""Create an area3D trigger for a room"""
	var area = Area3D.new()
	area.name = "RoomDetector"
	
	# Create collision shape based on approximate room size
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(15, 10, 15)  # Approximate room size
	collision.shape = box_shape
	
	area.add_child(collision)
	room_node.add_child(area)
	
	# Connect signals
	area.body_entered.connect(_on_room_entered.bind(room_node.name))
	area.body_exited.connect(_on_room_exited.bind(room_node.name))

func _on_room_entered(body: Node3D, room_name: String):
	if body == player:
		current_room = room_name
		if room_label:
			room_label.text = format_room_name(room_name)
		print("Entered room: ", format_room_name(room_name))

func _on_room_exited(body: Node3D, room_name: String):
	if body == player and current_room == room_name:
		# Player left the room, but we'll wait for them to enter a new one
		pass

func format_room_name(room_name: String) -> String:
	"""Convert room_name from snake_case to Title Case"""
	var formatted = room_name.replace("_", " ")
	var words = formatted.split(" ")
	var result = ""
	
	for word in words:
		if word.length() > 0:
			result += word[0].to_upper() + word.substr(1) + " "
	
	return result.strip_edges()
