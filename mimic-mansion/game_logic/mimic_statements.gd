class_name MimicStatements
extends Node


func _ready() -> void:
	pass


func parse_json(number_questions: int) -> Array:
	var json_text: String = FileAccess.open("res://data/ecg-data.json", FileAccess.READ).get_as_text()
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	
	if error != OK:
		push_error("Error parsing JSON: ", json.get_error_message())
		return []
	
	var data_received: Array = json.data.duplicate()

	data_received.shuffle()

	return data_received.slice(0, min(number_questions, data_received.size()))
