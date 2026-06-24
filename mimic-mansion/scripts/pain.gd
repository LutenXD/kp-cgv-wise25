@tool
extends EditorScript


const ROT_ROOMS_PATH = "res://assets/rot_rooms/"

# Called when the node enters the scene tree for the first time.
func _run() -> void:
	var dir = DirAccess.open(ROT_ROOMS_PATH)
	
	var names = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			names.append(file_name.replace(".tscn", ""))
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	
	print(names)
