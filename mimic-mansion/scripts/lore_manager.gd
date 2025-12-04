extends Node

class_name LoreManager

var all_lore_items: Array = []
var selected_lore_items: Array = []

func get_true_ratio() -> float:
	if has_node("/root/GameSettings"):
		return get_node("/root/GameSettings").get_true_ratio()
	return 0.5  # Default 50%

func _ready():
	load_lore_data()

func load_lore_data():
	var file_path = "res://data/lore/lore.json"
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				all_lore_items = json.data
				print("Loaded ", all_lore_items.size(), " lore items")
			else:
				push_error("Failed to parse lore.json: " + json.get_error_message())
	else:
		push_error("Could not find lore.json file at: " + file_path)

func select_random_lore_items(count: int = 10) -> Array:
	if all_lore_items.is_empty():
		push_error("No lore items loaded")
		return []
	
	var shuffled = all_lore_items.duplicate()
	shuffled.shuffle()
	
	selected_lore_items = shuffled.slice(0, min(count, shuffled.size()))
	
	# Get the true ratio from game settings
	var true_ratio = get_true_ratio()
	var num_true_items = int(count * true_ratio)
	
	# Assign true/false based on the ratio
	for i in range(selected_lore_items.size()):
		selected_lore_items[i]["is_true"] = i < num_true_items
	
	# Shuffle again to randomize the order of true/false items
	selected_lore_items.shuffle()
	
	print("Selected ", num_true_items, " true items and ", count - num_true_items, " false items")
	
	return selected_lore_items

func distribute_lore_to_spheres(lore_items: Array) -> Dictionary:
	if lore_items.size() < 10:
		push_error("Need at least 10 lore items")
		return {}
	
	var sphere_data = {
		"sphere1": [],
		"sphere2": [],
		"sphere3": []
	}
	
	# Collect all true items
	var true_items = []
	for item in lore_items:
		if item.get("is_true", false):
			true_items.append(item)
	
	# Distribute items ensuring each sphere gets 3 items
	# and true items appear in at least 2 spheres
	var available_items = lore_items.duplicate()
	available_items.shuffle()
	
	# Track which true items have been assigned and how many times
	var true_item_assignments = {}
	for item in true_items:
		true_item_assignments[item] = 0
	
	# Assign items to spheres
	var sphere_names = ["sphere1", "sphere2", "sphere3"]
	var item_index = 0
	
	# First pass: assign items to each sphere
	for sphere_name in sphere_names:
		for i in range(3):
			if item_index < available_items.size():
				var item = available_items[item_index]
				sphere_data[sphere_name].append(item)
				
				if item.get("is_true", false):
					if not true_item_assignments.has(item):
						true_item_assignments[item] = 0
					true_item_assignments[item] += 1
				
				item_index += 1
	
	# Second pass: ensure all true items appear in at least 2 spheres
	for true_item in true_item_assignments.keys():
		if true_item_assignments[true_item] < 2:
			# Find spheres that don't have this item
			var spheres_without_item = []
			for sphere_name in sphere_names:
				if not sphere_data[sphere_name].has(true_item):
					spheres_without_item.append(sphere_name)
			
			# Add to a random sphere that doesn't have it
			if not spheres_without_item.is_empty():
				var target_sphere = spheres_without_item[randi() % spheres_without_item.size()]
				
				# Replace the last false item in that sphere
				var replaced = false
				for i in range(sphere_data[target_sphere].size() - 1, -1, -1):
					if not sphere_data[target_sphere][i].get("is_true", false):
						sphere_data[target_sphere][i] = true_item
						replaced = true
						break
				
				# If no false item to replace, just add it
				if not replaced and sphere_data[target_sphere].size() < 4:
					sphere_data[target_sphere].append(true_item)
	
	return sphere_data
