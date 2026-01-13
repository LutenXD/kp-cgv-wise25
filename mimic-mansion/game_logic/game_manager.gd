extends Node3D


@export_multiline() var mimic_pre_instructions: String
@export_multiline() var mimic_post_instructions: String


@onready var mimic_container: Node3D = %MimicContainer
@onready var humgold: Evaluator = $Evaluator


func _ready() -> void:
	var mimic_statements = MimicStatements.new()
	var num_questions: int = mimic_container.get_children().size()
	var statements: Array[Dictionary] = mimic_statements.parse_json(num_questions)
	for i: int in range(num_questions):
		#print(str(statements[i]))
		mimic_container.get_child(i).set_instructions(mimic_pre_instructions + str(statements[i]) + mimic_post_instructions)
	
	#print(questions)
	humgold.num_questions = num_questions
	humgold.statements = statements
	humgold.set_evaluator_instructions()
