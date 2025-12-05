extends StaticBody3D

enum Honesty { HONEST, PARTIAL_LIAR, LIAR }

@export var sphere_name: String = "Sphere"
@export var sphere_id: String = "sphere1"
@export var proximity_range: float = 2.0  # Distance to show glow effect

var honesty: Honesty = Honesty.HONEST
var lie_count: int = 0  # Number of lies told
var truth_count: int = 0  # Number of truths told
var honesty_ratio: float = 1.0  # Ratio of truths (1.0 = all true, 0.0 = all lies)
var lore_items: Array = []

# Outline effect variables
var outline_mesh_instance: MeshInstance3D
var outline_material: StandardMaterial3D
var player_reference: CharacterBody3D
var is_glowing: bool = false

func set_lore_items(items: Array):
	lore_items = items
	# Calculate honesty statistics
	truth_count = 0
	lie_count = 0
	
	for item in lore_items:
		if item.get("is_true", true):
			truth_count += 1
		else:
			lie_count += 1
	
	# Calculate honesty ratio
	var total = truth_count + lie_count
	if total > 0:
		honesty_ratio = float(truth_count) / float(total)
	else:
		honesty_ratio = 1.0
	
	# Determine honesty type based on ratio
	if lie_count == 0:
		honesty = Honesty.HONEST
	elif truth_count == 0:
		honesty = Honesty.LIAR
	else:
		honesty = Honesty.PARTIAL_LIAR

func get_lore_items() -> Array:
	return lore_items

func get_info() -> Dictionary:
	var info_text = ""
	
	# Display honesty type
	var honesty_text = ""
	match honesty:
		Honesty.HONEST:
			honesty_text = "[color=green]Honest[/color]"
		Honesty.PARTIAL_LIAR:
			honesty_text = "[color=orange]Partial Liar[/color]"
		Honesty.LIAR:
			honesty_text = "[color=red]Liar[/color]"
	
	info_text += "Honesty: " + honesty_text + "\n"
	info_text += "Truths: " + str(truth_count) + " | Lies: " + str(lie_count) + "\n\n"
	
	if lore_items.is_empty():
		info_text += "No lore items assigned to this sphere."
	else:
		for i in range(lore_items.size()):
			var item = lore_items[i]
			var category = item.get("category", "Unknown")
			var description = item.get("description", "No description")
			var is_true = item.get("is_true", false)
			
			# Color code based on true/false
			var color = "green" if is_true else "red"
			
			info_text += "[color=" + color + "]" + str(i + 1) + ". [" + category + "]\n"
			info_text += description + "[/color]"
			if i < lore_items.size() - 1:
				info_text += "\n\n"
	
	return {
		"name": sphere_name,
		"text": info_text
	}

func _ready():
	# Find the player reference
	player_reference = get_node("../../player") if has_node("../../player") else null
	print("Sphere ", sphere_name, " initialized. Player reference: ", player_reference != null)
	
	# Create outline effect
	setup_outline_effect()

func setup_outline_effect():
	# Get the existing mesh instance
	var mesh_instance = get_node("MeshInstance3D")
	if not mesh_instance:
		return
	
	# Create outline material with fresnel-based rim lighting for outline effect
	outline_material = StandardMaterial3D.new()
	outline_material.flags_transparent = true
	outline_material.flags_unshaded = false  # Keep shaded for fresnel effect
	outline_material.cull_mode = BaseMaterial3D.CULL_FRONT  # Show only back faces for outline
	outline_material.no_depth_test = false
	outline_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	# Set up fresnel for rim lighting effect
	outline_material.rim_enabled = true
	outline_material.rim = 1.0
	outline_material.rim_tint = 0.5
	
	# Make it emissive for glow
	outline_material.emission_enabled = true
	outline_material.emission = Color(1.0, 0.1, 0.1, 1.0)  # Red emission
	outline_material.emission_energy = 2.0
	
	# Make base color less visible
	outline_material.albedo_color = Color(1.0, 0.2, 0.2, 0.1)  # Very transparent base
	
	# Create outline mesh instance (duplicate of the original)
	outline_mesh_instance = MeshInstance3D.new()
	outline_mesh_instance.mesh = mesh_instance.mesh
	outline_mesh_instance.material_override = outline_material
	outline_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Scale outline slightly larger to create true outline effect
	outline_mesh_instance.scale = Vector3(1.02, 1.02, 1.02)
	outline_mesh_instance.visible = false
	
	# Add as child
	add_child(outline_mesh_instance)

func _process(_delta):
	if player_reference and has_mimics():
		update_proximity_glow()

func has_mimics() -> bool:
	# Check if any lore items in this sphere are false (mimics)
	for item in lore_items:
		if not item.get("is_true", true):  # If item is false, it's a mimic
			return true
	return false

func update_proximity_glow():
	if not outline_mesh_instance:
		return
	
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var should_glow = distance_to_player <= proximity_range
	
	if should_glow and not is_glowing:
		show_glow()
	elif not should_glow and is_glowing:
		hide_glow()

func show_glow():
	if outline_mesh_instance:
		# Update glow color based on honesty type
		update_glow_color()
		outline_mesh_instance.visible = true
		is_glowing = true
		print("Showing glow for ", sphere_name, " (", Honesty.keys()[honesty], ")")
		# Animate the glow intensity
		animate_glow()

func update_glow_color():
	if not outline_material:
		return
	
	# Set glow color based on honesty type
	var emission_color: Color
	
	match honesty:
		Honesty.LIAR:
			# Pure red for complete liars
			emission_color = Color(1.0, 0.0, 0.0, 1.0)
		Honesty.PARTIAL_LIAR:
			# Orange for partial liars
			emission_color = Color(1.0, 0.3, 0.0, 1.0)
		_:
			# Shouldn't happen for mimics, but fallback to red
			emission_color = Color(1.0, 0.1, 0.1, 1.0)
	
	# Update only the emission for the outline glow
	outline_material.emission = emission_color
	# Keep albedo very transparent so only the rim/emission shows
	outline_material.albedo_color = Color(emission_color.r, emission_color.g, emission_color.b, 0.05)

func hide_glow():
	if outline_mesh_instance:
		outline_mesh_instance.visible = false
		is_glowing = false
		print("Hiding glow for ", sphere_name)

func animate_glow():
	if not outline_mesh_instance or not is_glowing:
		return
	
	# Create a pulsing effect
	var tween = create_tween()
	tween.set_loops()
	tween.tween_method(update_glow_intensity, 1.0, 3.0, 1.0)
	tween.tween_method(update_glow_intensity, 3.0, 1.0, 1.0)

func update_glow_intensity(intensity: float):
	if outline_material:
		outline_material.emission_energy = intensity
