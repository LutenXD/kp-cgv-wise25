extends StaticBody3D

@export var flicker_speed: float = 2.0
var noise = FastNoiseLite.new()
var time_offset = 0.0
var tween: Tween
func _ready() -> void:
	noise.seed = randi()
	noise.frequency = flicker_speed  # Adjust for flicker speed
	
func _process(delta):
	time_offset += delta
	
	# Sample noise for smooth, organic variation
	var flicker = noise.get_noise_1d(time_offset * 5.0)  # Speed multiplier
	var energy = 7.0 + flicker * 2.0  # Base 7.0, varies ±2.0
	$OmniLight3D.light_energy = energy
	
	# Optional: also vary the range
	var range_flicker = noise.get_noise_1d(time_offset * 3.0 + 100.0)
	$OmniLight3D.omni_range = 90.0 + range_flicker * 20.0
	
func animate_torch() -> void:
	if tween:
		tween.kill()
	var tween = get_tree().create_tween()
	tween.tween_property($OmniLight3D, "light_energy", 4.5+randf(), 1.5 + 0.5*randf()).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property($OmniLight3D, "light_energy", 8.0+randf(), 1.5 + 0.5*randf()).set_trans(Tween.TRANS_LINEAR)


func _on_timer_timeout() -> void:
	print("animate torch")
	animate_torch()
	$Timer.start(4.0 + 2.0*randf())
