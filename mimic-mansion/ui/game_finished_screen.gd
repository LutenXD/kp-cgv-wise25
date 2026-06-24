extends CanvasLayer


func _ready() -> void:
	hide()


func _on_new_game_button_pressed() -> void:
	get_tree().get_first_node_in_group("room_layout_manager").restart()


func _on_continue_button_pressed() -> void:
	$"..".continue_game()


func _on_exit_button_pressed() -> void:
	get_tree().quit()
