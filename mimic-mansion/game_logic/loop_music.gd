extends AudioStreamPlayer

@export var streams: Array[AudioStream] = []

var last_index := -1

func _ready():
	if streams.is_empty():
		return

	finished.connect(_on_finished)
	_play_random()

func _play_random():
	print("playing sfx")
	if streams.size() == 1:
		stream = streams[0]
		play()
		return

	var i := last_index

	# Reroll until different
	while i == last_index:
		i = randi() % streams.size()

	last_index = i
	stream = streams[i]
	play()

func _on_finished():
	_play_random()
