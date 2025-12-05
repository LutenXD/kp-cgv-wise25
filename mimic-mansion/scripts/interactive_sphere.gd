extends StaticBody3D

enum Honesty { HONEST, PARTIAL_LIAR, LIAR }

@export var sphere_name: String = "Sphere"
@export var sphere_id: String = "sphere1"

var honesty: Honesty = Honesty.HONEST
var lie_count: int = 0  # Number of lies told
var truth_count: int = 0  # Number of truths told
var honesty_ratio: float = 1.0  # Ratio of truths (1.0 = all true, 0.0 = all lies)
var lore_items: Array = []

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
