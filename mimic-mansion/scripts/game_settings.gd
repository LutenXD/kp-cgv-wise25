extends Node

# Game settings that persist across scenes
var true_item_ratio: float = 0.2  # Default 20% true items
var mimic_count: int = 3  # Default number of mimics to spawn
var game_in_progress: bool = false
var player_position: Vector3 = Vector3.ZERO
var selected_lore: Array = []
var sphere_assignments: Dictionary = {}
var selected_items: Array = []

func set_true_ratio(ratio: float):
	true_item_ratio = clamp(ratio, 0.0, 1.0)
	print("True item ratio set to: ", true_item_ratio * 100, "%")

func get_true_ratio() -> float:
	return true_item_ratio

func set_mimic_count(count: int):
	mimic_count = clamp(count, 1, 20)
	print("Mimic count set to: ", mimic_count)

func get_mimic_count() -> int:
	return mimic_count

func start_new_game():
	game_in_progress = true
	player_position = Vector3.ZERO
	selected_items = []
	print("New game started")

func save_game_state(player_pos: Vector3, lore: Array, spheres: Dictionary, selections: Array):
	game_in_progress = true
	player_position = player_pos
	selected_lore = lore
	sphere_assignments = spheres
	selected_items = selections
	print("Game state saved")

func load_game_state() -> Dictionary:
	return {
		"player_position": player_position,
		"selected_lore": selected_lore,
		"sphere_assignments": sphere_assignments,
		"selected_items": selected_items
	}

func is_game_in_progress() -> bool:
	return game_in_progress

func clear_game_state():
	game_in_progress = false
	player_position = Vector3.ZERO
	selected_lore = []
	sphere_assignments = {}
	selected_items = []
