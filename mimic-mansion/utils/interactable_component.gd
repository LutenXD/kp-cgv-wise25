class_name InteractableComponent
extends Node


signal interacted
signal send_audio(audio: AudioStreamWAV)


func interact_with() -> void:
	interacted.emit()


func receive_audio(audio: AudioStreamWAV) -> void:
	send_audio.emit(audio)
