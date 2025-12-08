class_name ChatRequest
extends HTTPRequest


signal text_answer_received(text: String)


const CHAT_URL: String = "https://llm.scads.ai/v1/chat/completions"
const API_KEY: String = "sk-lJKZ3tHOtQ7KgZP5ChABsw"


@export var chat_model: String = "alias-ha"
@export var system_instructions: String


var conversation: Array[Dictionary] = []


func _ready() -> void:
	self.request_completed.connect(_on_request_completed)


func request_chat(user_text: String) -> void:
	conversation.append({ "role": "user", "content": user_text })
	
	var headers: Array[String] = [
		"Content-Type: application/json",
		"Authorization: " + "Bearer " + API_KEY
	]
	
	var body: Dictionary[String, Variant] = {
		"model": chat_model,
		"messages": [
			{
				"role": "system",
				"content": system_instructions
			}
		] + conversation
	}
	
	self.request(
		CHAT_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != OK:
		push_error("HTTPRequest failed with result: %s" % result)
		return
	
	var text := body.get_string_from_utf8()
	if response_code != 200:
		push_error("Server error %s: %s" % [response_code, text])
		return
	
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid JSON: %s" % text)
		return
	
	var choices = data.get("choices", [])
	if choices.size() == 0:
		push_error("No choices in response: %s" % text)
		return
	
	var message_dict: Dictionary = choices[0].get("message", {})
	var ai_message: String = str(message_dict.get("content", ""))
	
	conversation.append({"role": "assistant", "content": ai_message})
	
	text_answer_received.emit(ai_message)
