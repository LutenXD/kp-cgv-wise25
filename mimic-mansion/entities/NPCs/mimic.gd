class_name Mimic
extends Node3D


@export_enum("openai/gpt-oss-120b", "meta-llama/Llama-3.3-70B-Instruct", "Qwen/Qwen3-Coder-30B-A3B-Instruct", "meta-llama/Llama-4-Scout-17B-16E-Instruct", "alias-ha") 
var chat_model: String = "alias-ha"

@export_enum("piper", "Kokoro-82M", "tts-1-hd") 
var tts_model: String = "Kokoro-82M"

@export_group("TTS Voice", "voice_")
## CRITICAL: must match the filename in res://addons/gdpiper/piper-voices
@export_enum("de_DE-thorsten_emotional-medium", "en_US-ljspeech-high", "fransop_finetune", "frm01-1000", "hans", "jacob", "frederik", "frans", "jans", "frob", "fransob", "bruno", "brans", "brob", "frunob", "fruno", "frunons", "janso", "jansunik") 
var voice_piper: String = "fransop_finetune"

@export_enum("af_heart", "am_echo", "af_river", "am_santa", "bm_fable") 
var voice_kokoro: String = "af_heart"

@export_enum("alloy", "echo", "fable", "nova", "shimmer")
var voice_tts_1: String = "fable"

@export_multiline var instructions: String = "Du bist ein böser NPC Geist in einem Videospiel, der versucht den Spieler in eine Falle zu locken. Antworte kurz und verwende keine Lautsprache."


var response: String
var tts_voice: String
var piper_thread: Thread
var hud: HUD
var speaking: bool = false

var thinking: bool = false
var wiggle_duration: float = 0.1
var wiggle_timer: float = 0.0
var wiggle_angle: float = PI / 64.0


@onready var stt_request: STTRequest = %STTRequest
@onready var chat_request: ChatRequest = %ChatRequest
@onready var tts_request: TTSRequest = %TTSRequest

@onready var audio_stream_player_3d: AudioStreamPlayer3D = %AudioStreamPlayer3D
@onready var gd_piper: GDPiper = $GDPiper #ich bin dran...  kp, ob ich das noch schaffe (läuft auf linux dev builds :/ )

@onready var bus_index: int = AudioServer.get_bus_index("Speech")
@onready var capture: AudioEffectCapture = AudioServer.get_bus_effect(bus_index, 0)


func _ready() -> void:
	match(tts_model):
		"piper":
			tts_voice = voice_piper
		"Kokoro-82M":
			tts_voice = voice_kokoro
		"tts-1-hd":
			tts_voice = voice_tts_1
	
	chat_request.chat_model = chat_model
	chat_request.system_instructions = instructions
	
	tts_request.tts_model = tts_model
	tts_request.tts_voice = tts_voice
	
	piper_thread = Thread.new()
	
	$DebugLabel.text = "TTS Model: " + tts_model + "\nVoice: " + tts_voice
	
	hud = get_tree().get_first_node_in_group("HUD")


func set_instructions(new_instructions: String) -> void:
	self.instructions = new_instructions
	chat_request.system_instructions = new_instructions


var left: bool = false
func _process(delta: float) -> void:
	if speaking:
		var prev_rms: float = 0.0
		var frames_available: int = capture.get_frames_available()
		if frames_available == 0:
			return
		
		var frames: PackedVector2Array = capture.get_buffer(frames_available)
		
		var rms_sum: float = 0.0
		
		for frame in frames:
			var sample = max(abs(frame.x), abs(frame.y))
			rms_sum += sample * sample
			
		var rms: float = sqrt(rms_sum / frames.size())
		
		#prints(" RMS:", rms)
		
		# wow magic numbers (exponential smoothing mit alpha = 1/4)
		$StaticBody3D/MeshInstance3D.position.y = 0.0 + rms * (4.0/16.0 + prev_rms * 12.0/16.0) * 2.0
		prev_rms = rms
	
	if thinking:
		if wiggle_timer > wiggle_duration and not left:
			left = true
		
		if wiggle_timer < 0.0 and left:
			left = false
		
		if left:
			delta *= -1.0
		
		wiggle_timer += delta

		$StaticBody3D/MeshInstance3D.rotation.y = lerp_angle(-wiggle_angle, wiggle_angle, ease(wiggle_timer / wiggle_duration, -2.0))
	else:
		wiggle_timer = 0.0
		$StaticBody3D/MeshInstance3D.rotation.y = 0.0


func _on_interactable_component_send_audio(audio: AudioStreamWAV) -> void:
	stt_request.request_stt(audio)
	thinking = true


func _on_stt_request_stt_answer_received(text: String) -> void:
	chat_request.request_chat(text)
	hud.set_subtitle("[color=green]" + text + "[/color]")
	prints("Transcript: ", text)


func _on_chat_request_text_answer_received(text: String) -> void:
	prints("Response: ", text)
	
	if tts_model == "piper":
		if piper_thread.is_started():
			piper_thread.wait_to_finish()
		piper_thread.start(_piper_tts.bind(text))
	else:
		tts_request.request_tts(text)
	response = text


var tts_stream: AudioStreamWAV
var stream_buffered: bool = false
func _piper_tts(text: String) -> void:
	tts_stream = gd_piper.tts(text, .5, tts_voice, 7)
	
	if self.audio_stream_player_3d.playing:
		stream_buffered = true
	else:
		audio_stream_player_3d.call_deferred("set_stream", tts_stream)
		audio_stream_player_3d.call_deferred("play")
	
	thinking = false
	speaking = true
	hud.call_deferred("append_subtitle", "\n" + text)


func _on_tts_request_tts_answer_received(audio: AudioStreamMP3) -> void:
	thinking = false
	speaking = true
	audio_stream_player_3d.set_stream(audio)
	audio_stream_player_3d.play()
	hud.set_subtitle(response)


func _exit_tree() -> void:
	piper_thread.wait_to_finish()


func _on_audio_stream_player_3d_finished() -> void:
	print("player finished")
	if stream_buffered:
		audio_stream_player_3d.stream = tts_stream
		audio_stream_player_3d.play()
		stream_buffered = false
	else:
		speaking = false
	
	#for player in get_tree().get_nodes_in_group("npc_player"):
		#if player is AudioStreamPlayer3D and player.playing:
			#return
	#hud.set_subtitle("")


func _on_chat_request_correctness_received(is_correct: bool) -> void:
	prints("correct?:", is_correct)
