@tool
class_name Evaluator
extends Mimic


@export_multiline() var evaluator_pre_instructions: String
@export_multiline() var evaluator_post_instructions: String


var statements: Array[Dictionary]
var num_questions: int
var question_idx: int = 0


@onready var score_label: Label3D = $ScoreLabel


func _ready() -> void:
	super._ready()
	score_label.text = str(question_idx) + "/" + str(num_questions)


func set_evaluator_instructions() -> void:
	if statements.is_empty():
		return
	self.set_instructions(evaluator_pre_instructions + str(statements[question_idx]) + evaluator_post_instructions)
	#print(str(statements[question_idx]))
	score_label.text = str(question_idx) + "/" + str(num_questions)


func _on_chat_request_correctness_received(is_correct: bool) -> void:
	if is_correct:
		question_idx += 1
		score_label.text = str(question_idx) + "/" + str(num_questions)
		if question_idx < num_questions:
			set_evaluator_instructions()
			self.chat_request.request_chat("ask away")
			thinking = true
		else:
			self.set_instructions(evaluator_pre_instructions + "every question was successfully answered. Praise the player!")
