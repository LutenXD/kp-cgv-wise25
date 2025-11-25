extends StaticBody3D

@export var sphere_name: String = "Sphere"
@export_multiline var info_text: String = "This is an interactive sphere."

func get_info() -> Dictionary:
	return {
		"name": sphere_name,
		"text": info_text
	}
