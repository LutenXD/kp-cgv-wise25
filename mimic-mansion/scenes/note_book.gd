extends Node3D

@export
var book_viewport: SubViewport
var text_edit: TextEdit
var anim_player: AnimationPlayer
var player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim_player = $AnimationPlayer
	if !book_viewport:
		book_viewport =$".".find_child("book_viewport")
		
	text_edit = book_viewport.find_child("TextEdit")
		#text_edit.focus_mode = Control.FOCUS_ALL
	#text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	book_viewport.gui_disable_input = false
	book_viewport.handle_input_locally = true
	await get_tree().process_frame
	text_edit.grab_focus()
	anim_player.play("appear")
	
	
	player = get_tree().get_first_node_in_group("player")
		
	if player:
		print("disabling player input while writing in notebook")
		player.set_process(false)
		player.set_physics_process(false)
	else:
		print("player group not found, cant disable controls while writing")

func _input(event):
	if book_viewport:
		book_viewport.push_input(event)
#	if player:
#		Input.is_action_just_pressed("close_book")
#		player.set_process(true)
#		player.set_physics_process(true)
	pass
	
