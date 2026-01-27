class_name MimicStatements
extends Node


func _ready() -> void:
	pass


func parse_json(number_questions: int) -> Array[Dictionary]:
	var json_text: String = FileAccess.open("res://data/ecg-data.json", FileAccess.READ).get_as_text()
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	
	if error != OK:
		push_error("Error parsing JSON: ", json.get_error_message())
		return []
	
	var data_received: Array = json.data
	
	var resulting_questions: Array[Dictionary] = []
	for i in range(number_questions):
		resulting_questions.append(data_received[randi() % data_received.size()])
	
	#print(resulting_questions)
	#print(typeof(resulting_questions[0]))
	
	return resulting_questions
