extends SubViewport


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	size = get_viewport().get_visible_rect().size
