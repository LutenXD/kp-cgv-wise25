extends Node3D

@export
var book_viewport: SubViewport
var text_edit: TextEdit
var anim_player: AnimationPlayer
var menu: CanvasLayer
var player


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	menu = $CanvasLayer
	anim_player = $AnimationPlayer
	if !book_viewport:
		book_viewport =$".".find_child("book_viewport")
	
	menu.hide()
	text_edit = book_viewport.find_child("TextEdit")
	player = get_tree().get_first_node_in_group("Player")
		#text_edit.focus_mode = Control.FOCUS_ALL
	#text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	
	
func _input(event):
	if visible && event.is_action_released("pause"):
		deactivate_book()
	if book_viewport && visible:
		book_viewport.push_input(event)
	elif event.is_action_pressed("open_book"):
		activate_book()
#	if player:
#		Input.is_action_just_pressed("close_book")
#		player.set_process(true)
#		player.set_physics_process(true)

	
func activate_book():
	anim_player.play("appear")
	await get_tree().process_frame
	show()
	menu.show()
	await get_tree().process_frame
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	book_viewport.gui_disable_input = false
	book_viewport.handle_input_locally = true
	await get_tree().process_frame
	text_edit.grab_focus()
	
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	
func deactivate_book():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	book_viewport.gui_disable_input = true
	book_viewport.handle_input_locally = false
	await get_tree().process_frame
	menu.hide()
	text_edit.release_focus()
	#anim_player.play("appear")
	#TODO: disappear animation
	hide()
		
	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process_unhandled_input(true)


func _on_close_button_pressed() -> void:
	deactivate_book()
	pass # Replace with function body.
