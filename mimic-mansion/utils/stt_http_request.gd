class_name STTRequest
extends HTTPRequest


signal stt_answer_received(text: String)


const STT_URL: String = "https://llm.scads.ai/v1/audio/transcriptions"
const STT_MODEL: String = "openai/whisper-large-v3"
const API_KEY: String = "sk-lJKZ3tHOtQ7KgZP5ChABsw"


var is_requesting: bool = false
var pending_requests: Array[AudioStreamWAV]


func _ready() -> void:
	self.request_completed.connect(_on_stt_request_completed)


func request_stt(recording: AudioStreamWAV) -> void:
	if is_requesting:
		#print("\nbuffering tts request\n")
		pending_requests.append(recording)
		return
	
	is_requesting = true
	
	if recording == null:
		push_error("recording empty")
		return
	
	var tmp_path: String = "user://recording.wav"
	
	if recording.save_to_wav(tmp_path) != OK:
		push_error("error saving recording")
		return
	
	var file_bytes: PackedByteArray = FileAccess.get_file_as_bytes(tmp_path)
	if file_bytes.is_empty():
		push_error("error reading saved recording")
		return
	
	var boundary := "----GodotBoundary" + str(Time.get_ticks_msec())
	var content_type := "multipart/form-data; boundary=" + boundary
	var body := PackedByteArray()
	
	var headers: Array[String] = [
		"Authorization: Bearer " + API_KEY,
		"Content-Type: " + content_type
	]
	
	# file
	body += ("--" + boundary + "\r\n").to_utf8_buffer()
	body += 'Content-Disposition: form-data; name="file"; filename="recording.wav"\r\n'.to_utf8_buffer()
	body += "Content-Type: audio/wav\r\n\r\n".to_utf8_buffer()
	body += file_bytes
	body += "\r\n".to_utf8_buffer()
	
	# model
	body += ("--" + boundary + "\r\n").to_utf8_buffer()
	body += 'Content-Disposition: form-data; name="model"\r\n\r\n'.to_utf8_buffer()
	body += STT_MODEL.to_utf8_buffer()
	body += "\r\n".to_utf8_buffer()
	
	# language
	body += ("--" + boundary + "\r\n").to_utf8_buffer()
	body += 'Content-Disposition: form-data; name="language"\r\n\r\n'.to_utf8_buffer()
	body += "en".to_utf8_buffer()
	body += "\r\n".to_utf8_buffer()
	
	body += ("--" + boundary + "--\r\n").to_utf8_buffer()
	
	var err: Error = self.request_raw(
		STT_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	
	if err != OK:
		push_error("Failed to start STT HTTPRequest: %s" % err)


func _on_stt_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != OK:
		push_error("STT request failed with result: %s" % result)
		return
	
	var raw_text: String = body.get_string_from_utf8()
	if response_code != 200:
		push_error("STT server error %s: %s" % [response_code, raw_text])
		return
	
	var data = JSON.parse_string(raw_text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("STT invalid JSON: %s" % raw_text)
		return
	
	var transcript: String = str(data.get("text", ""))
	
	stt_answer_received.emit(transcript)
	
	is_requesting = false
	if pending_requests.size() > 0:
		request_stt(pending_requests.pop_front())
