extends Node
class_name Flicker

var all_lights: Array[Node]
var flicker_timers = {}
var original_energies = {}  # Store original light energy values
@export var min_flicker_time: float
@export var max_flicker_time: float

func _ready():
	pass

func _physics_process(delta):
	for light in all_lights:
		if not light in flicker_timers:
			continue
			
		flicker_timers[light] -= delta
		if flicker_timers[light] <= 0:
			flicker_light(light)
			schedule_next_flicker(light)

func flicker_light(light: Light3D):
	var tween = get_tree().create_tween()
	var original_energy = original_energies.get(light, 1.0)
	
	# Type of flicker (weighted probabilities)
	var flicker_type = randf()
	
	if flicker_type < 0.6:  # 60% chance: quick double flicker
		tween.tween_property(light, "light_energy", 0.0, 0.03)
		tween.tween_property(light, "light_energy", 0.0, 0.08)
		tween.tween_property(light, "light_energy", original_energy, 0.03)
		tween.tween_property(light, "light_energy", original_energy, 0.15)
		tween.tween_property(light, "light_energy", 0.0, 0.03)
		tween.tween_property(light, "light_energy", 0.0, 0.05)
		tween.tween_property(light, "light_energy", original_energy, 0.03)
		
	elif flicker_type < 0.85:  # 25% chance: struggling to turn on
		for i in range(randi_range(3, 6)):
			tween.tween_property(light, "light_energy", 0.0, 0.04)
			tween.tween_property(light, "light_energy", 0.0, randf_range(0.08, 0.2))
			tween.tween_property(light, "light_energy", original_energy * randf_range(0.3, 0.8), 0.04)
			tween.tween_property(light, "light_energy", original_energy * randf_range(0.3, 0.8), 0.05)
		tween.tween_property(light, "light_energy", original_energy, 0.05)
		
	else:  # 15% chance: single quick blink
		tween.tween_property(light, "light_energy", 0.0, 0.02)
		tween.tween_property(light, "light_energy", 0.0, 0.06)
		tween.tween_property(light, "light_energy", original_energy, 0.02)

func schedule_next_flicker(light: Light3D):
	flicker_timers[light] = randf_range(min_flicker_time, max_flicker_time)  # 15-90 seconds between flickersextends Node


func _on_room_layout_manager_finished() -> void:
	await get_tree().process_frame
	all_lights = get_tree().get_nodes_in_group("flickering_light")
	for light in all_lights:
		original_energies[light] = light.light_energy
		schedule_next_flicker(light)


func _on_room_layout_manager_2_finished() -> void:
	await get_tree().process_frame
	all_lights = get_tree().get_nodes_in_group("flickering_light")
	for light in all_lights:
		original_energies[light] = light.light_energy
		schedule_next_flicker(light)


func _on_room_layout_manager_3_finished() -> void:
	await get_tree().process_frame
	all_lights = get_tree().get_nodes_in_group("flickering_light")
	for light in all_lights:
		original_energies[light] = light.light_energy
		schedule_next_flicker(light)
