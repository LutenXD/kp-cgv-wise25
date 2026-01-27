@tool
extends EditorScript


const SOURCE_ROOT := "res://assets/props-50k"
const DEST_ROOT   := "res://assets/prop-scenes-50k"


func _run():
	var dir := DirAccess.open(SOURCE_ROOT)
	if dir == null:
		push_error("Source root does not exist: " + SOURCE_ROOT)
		return
		
	_process_directory(SOURCE_ROOT, DEST_ROOT)
	print("Folder processing completed.")


func _process_directory(src_path: String, dst_path: String) -> void:
	# Ensure destination directory exists
	DirAccess.make_dir_recursive_absolute(dst_path)
	
	var dir := DirAccess.open(src_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var glb_files: Array[String] = []
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var src_full := src_path + "/" + file_name
		var dst_full := dst_path + "/" + file_name
		
		if dir.current_is_dir():
			_process_directory(src_full, dst_full)
		else:
			if file_name.get_extension().to_lower() == "glb":
				glb_files.append(src_full)
		
		file_name = dir.get_next()
		
	dir.list_dir_end()
	
	for glb in glb_files:
		_create_scene_from_glb(glb, dst_path)


func _create_scene_from_glb(glb_path: String, dst_path: String) -> void:
	var glb_scene := load(glb_path)
	if glb_scene == null:
		push_error("Failed to load GLB: " + glb_path)
		return
	
	var glb_instance = glb_scene.instantiate()
	var mesh_instances := _find_mesh_instances(glb_instance)
	
	if mesh_instances.is_empty():
		push_error("No MeshInstance3D found in: " + glb_path)
		return
	
	# Root StaticBody3D
	var static_body := StaticBody3D.new()
	
	static_body.name = glb_path.get_file().get_basename()
	
	for mesh_instance in mesh_instances:
		mesh_instance.get_parent().remove_child(mesh_instance)
		mesh_instance.owner = null
		static_body.add_child(mesh_instance)
		mesh_instance.owner = static_body
		
		# Collision
		if mesh_instance.mesh:
			var shape := mesh_instance.mesh.create_convex_shape(true, true)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			static_body.add_child(collision)
			#collision.rotation.x = PI / 2.0
			collision.owner = static_body
	
	# Create scene
	var packed_scene := PackedScene.new()
	packed_scene.pack(static_body)
	
	var scene_name := glb_path.get_file().get_basename() + ".tscn"
	var save_path := dst_path + "/" + scene_name
	
	var err := ResourceSaver.save(packed_scene, save_path)
	if err != OK:
		push_error("Failed to save scene: " + save_path)
	else:
		print("Created scene: ", save_path)


func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		if child is Node:
			result.append_array(_find_mesh_instances(child))
	
	return result
