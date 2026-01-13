class_name ChatRequest
extends HTTPRequest


signal text_answer_received(text: String)
signal correctness_received(is_correct: bool)


const CHAT_URL: String = "https://llm.scads.ai/v1/chat/completions"
const API_KEY: String = "sk-lJKZ3tHOtQ7KgZP5ChABsw"


@export var chat_model: String = "alias-ha"
@export var system_instructions: String


var conversation: Array[Dictionary] = []
var is_requesting: bool = false
var pending_requests: Array[String]


func _ready() -> void:
	self.request_completed.connect(_on_request_completed)


func request_chat(user_text: String) -> void:
	if is_requesting:
		print("\nbuffering chat request\n")
		pending_requests.append(user_text)
		return
	
	is_requesting = true
	
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
				"content": "Always respond with JSON: { \"content\": string, \"is_correct\": boolean }. " + system_instructions
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
	
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		push_error("No choices in response: %s" % text)
		return
	
	var message_dict: Dictionary = choices[0].get("message", {})
	var content: String = str(message_dict.get("content", ""))
	
	var parsed = JSON.parse_string(content)
	var ai_text := ""
	var is_correct = null

	if typeof(parsed) == TYPE_DICTIONARY:
		ai_text = str(parsed.get("content", ""))
		if parsed.has("is_correct"):
			is_correct = bool(parsed["is_correct"])
	else:
		ai_text = str(content)

	# Store ONLY text in conversation
	conversation.append({
		"role": "assistant",
		"content": ai_text
	})
	
	text_answer_received.emit(ai_text)
	
	if is_correct != null:
		correctness_received.emit(is_correct)
	
	is_requesting = false
	if pending_requests.size() > 0:
		request_chat(pending_requests.pop_front())
