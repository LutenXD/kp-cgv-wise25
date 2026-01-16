@tool
extends EditorScript

const ROOT_DIR := "res://assets/textures/materials"

func _run():
	var dir := DirAccess.open(ROOT_DIR)
	if dir == null:
		push_error("Could not open " + ROOT_DIR)
		return
	
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			_process_material_folder(folder_name)
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	print("Material generation complete.")


func _process_material_folder(name: String):
	var folder_path := ROOT_DIR + "/" + name
	var material_path := folder_path + ".tres"
	
	print("Creating material:", name)
	
	var mat := StandardMaterial3D.new()
	
	_assign_texture(mat, folder_path, "albedo.png", "albedo_texture")
	_assign_texture(mat, folder_path, "normal.png", "normal_texture")
	_assign_texture(mat, folder_path, "roughness.png", "roughness_texture")
	_assign_texture(mat, folder_path, "metallic.png", "metallic_texture")
	_assign_texture(mat, folder_path, "height.png", "heightmap_texture")
	
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	
	mat.heightmap_enabled = true
	mat.normal_enabled = true
	mat.uv1_scale = Vector3(10.0, 10.0, 10.0)
	
	ResourceSaver.save(mat, material_path)


func _assign_texture(mat: StandardMaterial3D, folder: String, file: String, property: String):
	var path := folder + "/" + file
	if not ResourceLoader.exists(path):
		return
	
	var tex := load(path)
	if tex == null:
		return
	
	mat.set(property, tex)
