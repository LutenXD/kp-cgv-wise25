extends TextEdit


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("focus", sb)
	add_theme_stylebox_override("read_only", sb)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
