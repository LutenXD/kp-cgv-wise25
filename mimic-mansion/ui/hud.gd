extends CanvasLayer
class_name HUD


@export var player: Player


@onready var interaction_label: Label = %InteractionLabel
@onready var caption_text_label: RichTextLabel = $CaptionTextLabel


func _ready() -> void:
	pass # Replace with function body.


func _process(_delta: float) -> void:
	interaction_label.visible = not player.current_interaction == null


func set_subtitle(text: String) -> void:
	caption_text_label.text = text
