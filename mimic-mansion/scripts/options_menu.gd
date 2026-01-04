extends Control

@onready var true_ratio_slider = $CenterContainer/VBoxContainer/RatioContainer/TrueRatioSlider
@onready var ratio_label = $CenterContainer/VBoxContainer/RatioContainer/RatioLabel
@onready var mimic_count_slider = $CenterContainer/VBoxContainer/MimicContainer/MimicCountSlider
@onready var mimic_label = $CenterContainer/VBoxContainer/MimicContainer/MimicLabel

func _ready():
	# Ensure the mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Initialize sliders with current settings
	var settings = get_game_settings()
	if settings:
		if true_ratio_slider:
			true_ratio_slider.value = settings.get_true_ratio() * 100
		if mimic_count_slider:
			mimic_count_slider.value = settings.get_mimic_count()
	
	update_ratio_label()
	update_mimic_label()

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

func _on_mimic_count_slider_value_changed(value: float):
	var settings = get_game_settings()
	if settings:
		settings.set_mimic_count(int(value))
	update_mimic_label()

func update_mimic_label():
	if mimic_label and mimic_count_slider:
		var count = int(mimic_count_slider.value)
		mimic_label.text = "Number of Mimics: " + str(count)

func _on_generate_layout_button_pressed():
	# Open the room layout generator scene
	get_tree().change_scene_to_file("res://scenes/room_layout_preview.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
