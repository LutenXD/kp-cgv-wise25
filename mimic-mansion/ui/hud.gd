extends CanvasLayer


@export var player: Player


@onready var interaction_label: Label = %InteractionLabel


func _ready() -> void:
	pass # Replace with function body.


func _process(_delta: float) -> void:
	interaction_label.visible = not player.current_interaction == null
