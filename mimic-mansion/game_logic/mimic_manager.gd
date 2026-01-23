class_name MimicManager
extends Node3D


@export_multiline() var mimic_pre_instructions: String
@export_multiline() var mimic_post_instructions: String
@export var humgold: Evaluator


@onready var room_layout_manager: RoomLayoutManager = $"../RoomLayoutManager"


func _ready() -> void:
	var mimic_statements = MimicStatements.new()
	var mimics: Array[Node] = get_tree().get_nodes_in_group("mimic")
	var num_questions: int = mimics.size()
	var statements: Array[Dictionary] = mimic_statements.parse_json(num_questions)
	for i: int in range(num_questions):
		#print(str(statements[i]))
		mimics[i].set_instructions(mimic_pre_instructions + str(statements[i]) + mimic_post_instructions)
	
	humgold.num_questions = num_questions
	humgold.statements = statements
	await get_tree().process_frame # fuck this
	humgold.set_evaluator_instructions()
	
	room_layout_manager.spawn_starting_room()
