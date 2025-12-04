extends Control

@onready var true_ratio_slider = $CenterContainer/VBoxContainer/RatioContainer/TrueRatioSlider
@onready var ratio_label = $CenterContainer/VBoxContainer/RatioContainer/RatioLabel

func _ready():
	# Ensure the mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Initialize slider with current settings
	if true_ratio_slider:
		var settings = get_game_settings()
		if settings:
			true_ratio_slider.value = settings.get_true_ratio() * 100
		update_ratio_label()

func get_game_settings():
	if has_node("/root/GameSettings"):
		return get_node("/root/GameSettings")
	return null

func _on_true_ratio_slider_value_changed(value: float):
	var settings = get_game_settings()
	if settings:
		settings.set_true_ratio(value / 100.0)
	update_ratio_label()

func update_ratio_label():
	if ratio_label and true_ratio_slider:
		var percent = int(true_ratio_slider.value)
		ratio_label.text = "True Items: " + str(percent) + "% / False Items: " + str(100 - percent) + "%"

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
