class_name TTSRequest
extends HTTPRequest


signal tts_answer_received(audio: AudioStreamWAV)


const TTS_URL: String = "https://llm.scads.ai/v1/audio/speech"
const API_KEY: String = "sk-lJKZ3tHOtQ7KgZP5ChABsw"


@export var tts_model: String = "Kokoro-82M"
@export var tts_voice: String = "am_echo"

var is_requesting: bool = false
var pending_requests: Array[String]


func _ready() -> void:
	self.request_completed.connect(_on_request_completed)


func request_tts(text: String) -> void:
	if is_requesting:
		#print("\nbuffering tts request\n")
		pending_requests.append(text)
		return
	
	is_requesting = true
	
	var headers: Array[String] = [
		"Content-Type: application/json",
		"Authorization: Bearer " + API_KEY
	]
	
	var body := {
		"model": tts_model,
		"input": text,
		"voice": tts_voice,
		"response_format": "mp3"
	}
	
	self.request(
		TTS_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != OK:
		push_error("TTS request failed with result: %s" % result)
		return
	
	if response_code != 200:
		var err_text := body.get_string_from_utf8()
		push_error("TTS server error %s: %s" % [response_code, err_text])
		return
	
	
	var wav_stream: AudioStreamMP3 = AudioStreamMP3.load_from_buffer(body)
	
	tts_answer_received.emit(wav_stream)
	
	is_requesting = false
	if pending_requests.size() > 0:
		request_tts(pending_requests.pop_front())
