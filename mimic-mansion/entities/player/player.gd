class_name Player
extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5


var look_sensitivity: float = 0.001
var current_interaction: InteractableComponent
var last_interaction: InteractableComponent
var effect: AudioEffectRecord
var recording: AudioStreamWAV
var currently_recording: bool = false
var flying: bool = false


@onready var interaction_shape_cast_3d: ShapeCast3D = %InteractionShapeCast3D
@onready var audio_stream_record: AudioStreamPlayer = %AudioStreamRecord


func _ready() -> void:
	var idx = AudioServer.get_bus_index("Record")
	effect = AudioServer.get_bus_effect(idx, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fly"):
		flying = not flying
		$CollisionShape3D.disabled = flying
		prints("flying: ", str(flying))
	
	if event.is_action("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			self.rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _process(_delta: float) -> void:
	current_interaction = get_interactable_component_at_shapecast()
	if current_interaction:
		if Input.is_action_just_pressed("interact"):
			current_interaction.interact_with()
			last_interaction = current_interaction
			record_audio()
	
	if last_interaction and currently_recording:
		if Input.is_action_just_released("interact"):
			record_audio()
			last_interaction.receive_audio(recording)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor() and not flying:
		velocity += get_gravity() * delta
	
	# Handle jump.
	#if Input.is_action_just_pressed("jump") and is_on_floor():
		#velocity.y = JUMP_VELOCITY
	
	var input_dir := Input.get_vector("strafe_left", "strafe_right", "forward", "backward")
	var direction := (self.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction and not flying:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	elif direction and flying:
		direction = (%Camera3D.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		velocity.x = direction.x * SPEED * 2.0
		velocity.y = direction.y * SPEED * 2.0
		velocity.z = direction.z * SPEED * 2.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.y = move_toward(velocity.y, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	
	move_and_slide()


func get_interactable_component_at_shapecast() -> InteractableComponent:
	for i in %InteractionShapeCast3D.get_collision_count():
		var collider = %InteractionShapeCast3D.get_collider(i)
		if collider and collider.get_node_or_null("InteractableComponent") is InteractableComponent:
			return collider.get_node_or_null("InteractableComponent")
	return null


func record_audio() -> void:
	currently_recording = not currently_recording
	if effect.is_recording_active():
		recording = effect.get_recording()
		effect.set_recording_active(false)
		print("recording finished")
	else:
		effect.set_recording_active(true)
		print("recording started")
