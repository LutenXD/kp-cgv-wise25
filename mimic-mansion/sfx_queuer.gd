extends AudioStreamPlayer3D

var player: AudioStreamPlayer3D = self
@export_range(0.0, 600.0, 0.1) var min_interval_sec := 2.0
@export_range(0.0, 600.0, 0.1) var max_interval_sec := 6.0

# Optional: avoid interrupting an already-playing clip.
@export var wait_until_finished := true

var _timer: Timer
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

	if player == null:
		push_error("RandomIntervalStreamPlayer: 'player' is not assigned.")
		return

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)

	_schedule_next()

func _schedule_next() -> void:
	if max_interval_sec < min_interval_sec:
		# Swap if user set them backwards.
		var tmp := min_interval_sec
		min_interval_sec = max_interval_sec
		max_interval_sec = tmp

	var wait := _rng.randf_range(min_interval_sec, max_interval_sec)
	_timer.start(wait)

func _on_timer_timeout() -> void:
	if wait_until_finished and player.playing:
		# Poll again soon until the clip ends.
		_timer.start(0.1)
		return

	# If player.stream is an AudioStreamRandomizer, it will pick a random substream on play().
	player.play()

	_schedule_next()
