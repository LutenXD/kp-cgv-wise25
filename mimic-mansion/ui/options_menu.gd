extends CanvasLayer


signal close_options


@onready var sens_slider: HSlider = %SensSlider
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider



func _ready():
	hide()
	sens_slider.value = Settings.mouse_sensitivity
	master_slider.value = Settings.volume_master
	music_slider.value = Settings.volume_music
	sfx_slider.value = Settings.volume_sound


func _on_back_button_pressed():
	close_options.emit()


func _on_sens_slider_value_changed(value: float) -> void:
	Settings.mouse_sensitivity = value


func _on_master_slider_value_changed(value: float) -> void:
	Settings.volume_master = value


func _on_music_slider_value_changed(value: float) -> void:
	Settings.volume_music = value


func _on_sfx_slider_value_changed(value: float) -> void:
	Settings.volume_sound = value
