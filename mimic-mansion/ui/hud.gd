extends CanvasLayer
class_name HUD


@export var player: Player


@onready var interaction_label: Label = %InteractionLabel
@onready var caption_text_label: RichTextLabel = $CaptionTextLabel
@onready var fps_label: Label = $FPSLabel
@onready var PauseMenu: CanvasLayer = $PauseMenu
@onready var OptionsMenu: CanvasLayer = $OptionsMenu
@onready var GameFinishedScreen: CanvasLayer = %GameFinishedScreen



func _ready() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(_delta: float) -> void:
	#interaction_label.visible = not player.current_interaction == null
	fps_label.text = str(Engine.get_frames_per_second())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().get_first_node_in_group("note_book").visible:
			return
		if !PauseMenu.visible && !OptionsMenu.visible:
			PauseMenu.show()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_tree().paused = true
			print("opening menu")
		elif OptionsMenu.visible:
			print("closing options")
			OptionsMenu.hide()
		else:
			print("closing menu")
			continue_game()


func continue_game():
	# Continue the existing game
	#get_tree().change_scene_to_file("res://scenes/game.tscn")
	PauseMenu.hide()
	OptionsMenu.hide()
	GameFinishedScreen.hide()
	call_deferred("_capture_mouse")
	get_tree().paused = false


func _on_exit_button_pressed():
	get_tree().quit()


func _on_main_menu_continue_game() -> void:
	continue_game()


func _on_pause_menu_open_settings() -> void:
	OptionsMenu.show()


func _on_options_menu_close_options() -> void:
	OptionsMenu.hide()


func set_subtitle(text: String) -> void:
	caption_text_label.text = text


func append_subtitle(text: String) -> void:
	caption_text_label.text += text


func finish_game() -> void:
	$GameFinishedScreen.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
