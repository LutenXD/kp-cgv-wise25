@tool
extends StaticBody3D
@export var model: PackedScene

"""
create inherited scenes of this scene 
and pull glb into inspector to import props
"""
func _ready() -> void:
	var node: Node3D = model.instantiate()
	var mesh: MeshInstance3D = node.get_child(0).get_child(0)
	node.get_child(0).remove_child(mesh)
	add_child(mesh)
	mesh.create_convex_collision(true, true)
