extends CanvasLayer


func _ready() -> void:
	hide()


func _on_new_game_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_continue_button_pressed() -> void:
	$".".continue_game()


func _on_exit_button_pressed() -> void:
	get_tree().quit()
