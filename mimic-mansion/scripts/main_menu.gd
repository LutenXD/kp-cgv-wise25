extends Control

const SAVE_PATH = "user://savegame.save"

@onready var continue_button = $CenterContainer/VBoxContainer/ContinueButton
@onready var options_popup = $OptionsPopup

func _ready():
	# Check if a save file exists and enable/disable the continue button
	if FileAccess.file_exists(SAVE_PATH):
		continue_button.disabled = false
	else:
		continue_button.disabled = true
	
	# Ensure the mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_new_game_button_pressed():
	# Delete existing save file if starting a new game
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	
	# Load the game scene
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_continue_button_pressed():
	# Load the saved game
	load_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_options_button_pressed():
	options_popup.popup_centered()

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
