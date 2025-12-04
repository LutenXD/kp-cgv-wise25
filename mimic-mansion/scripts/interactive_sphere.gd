extends StaticBody3D

@export var sphere_name: String = "Sphere"
@export var sphere_id: String = "sphere1"

var lore_items: Array = []

func set_lore_items(items: Array):
	lore_items = items

func get_lore_items() -> Array:
	return lore_items

func get_info() -> Dictionary:
	var info_text = ""
	
	if lore_items.is_empty():
		info_text = "No lore items assigned to this sphere."
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
