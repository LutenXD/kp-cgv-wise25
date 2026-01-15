extends CanvasLayer

const SAVE_PATH = "user://savegame.save"

@onready var continue_button = $CenterContainer/VBoxContainer/ContinueButton

signal open_settings()
signal continue_game()

func _ready():
	# Check if game is in progress
	#var settings = get_game_settings()
	#if settings and settings.is_game_in_progress():
	#	continue_button.disabled = false
	#else:
	#	continue_button.disabled = true
		
	hide()
	
	# Ensure the mouse is visible
	#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func get_game_settings():
	if has_node("/root/GameSettings"):
		return get_node("/root/GameSettings")
	return null


func _on_new_game_button_pressed():
	# Clear any existing game state
	var settings = get_game_settings()
	if settings:
		settings.clear_game_state()
		settings.start_new_game()
	
	# Load the game scene
	emit_signal("continue_game")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_continue_button_pressed():
	# Continue the existing game
	#get_tree().change_scene_to_file("res://scenes/game.tscn")
	# hud.gd script is connected and will unpause the tree and hide all menus
	emit_signal("continue_game")

func _on_options_button_pressed():
	emit_signal("open_settings")

func _on_exit_button_pressed():
	get_tree().quit()

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file:
		var json_string = save_file.get_line()
		save_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var save_data = json.data
			# Store the save data in an autoload/global script
			# For now, we'll just print it
			print("Loaded save data: ", save_data)
			# TODO: Apply save data to game state
