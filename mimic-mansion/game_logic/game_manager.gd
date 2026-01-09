extends Node3D


@export_multiline() var mimic_pre_instructions: String


@onready var mimic_container: Node3D = %MimicContainer


func _ready() -> void:
	var mimic_statements = MimicStatements.new()
	var statements: Array[Dictionary] = mimic_statements.parse_json(4)
	for i: int in range(mimic_container.get_children().size()):
		print(str(statements[i]))
		mimic_container.get_child(i).instructions = mimic_pre_instructions + str(statements[i])
	
	for mimic: Mimic in mimic_container.get_children():
		mimic._ready()
		print(mimic.instructions)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
