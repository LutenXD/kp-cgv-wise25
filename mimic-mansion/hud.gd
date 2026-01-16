extends Control

@onready var PauseMenu: CanvasLayer = $PauseMenu
@onready var OptionsMenu: CanvasLayer = $OptionsMenu

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass # Replace with function body.
		
		
func _capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") \
	&& !PauseMenu.visible && !OptionsMenu.visible:
		PauseMenu.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true
		print("opening menu")
		
	elif event.is_action_pressed("pause"):
		print("closing menu")
		continue_game()


func continue_game():
	# Continue the existing game
	#get_tree().change_scene_to_file("res://scenes/game.tscn")
	PauseMenu.hide()
	OptionsMenu.hide()
	call_deferred("_capture_mouse")
	get_tree().paused = false


func _on_exit_button_pressed():
	get_tree().quit()


func _on_main_menu_continue_game() -> void:
	continue_game()


func _on_pause_menu_open_settings() -> void:
	PauseMenu.hide()
	OptionsMenu.show()


func _on_options_menu_close_options() -> void:
	OptionsMenu.hide()
	PauseMenu.show()
