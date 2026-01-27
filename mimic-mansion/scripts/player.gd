extends CharacterBody3D

const SPEED = 5.0
const FLY_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

@onready var camera = $Camera3D

var fly_mode = false

func _ready():
	# Capture the mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Handle mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate player horizontally
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Rotate camera vertically
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		
		# Clamp vertical rotation to prevent flipping
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	# Press ESC to release mouse cursor
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Press F to toggle fly mode (only if debug mode is enabled)
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
		if get_debug_mode():
			fly_mode = !fly_mode
			print("Fly mode: ", "ON" if fly_mode else "OFF")
		else:
			print("Debug mode is disabled. Enable it in Options to use fly mode.")

func get_debug_mode() -> bool:
	if has_node("/root/GameSettings"):
		return get_node("/root/GameSettings").get_debug_mode()
	return false

func _physics_process(delta: float) -> void:
	if fly_mode:
		# Fly mode: free movement in all directions, no collision
		fly_movement(delta)
	else:
		# Normal mode: walking with gravity and collision
		normal_movement(delta)

func fly_movement(delta: float):
	"""No-clip fly mode with free 3D movement"""
	# Get the input direction using WASD
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	# Calculate horizontal movement
	var direction := Vector3.ZERO
	direction += transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	
	# Add vertical movement with Space (up) and Shift (down)
	if Input.is_key_pressed(KEY_SPACE):
		direction.y += 1
	if Input.is_key_pressed(KEY_SHIFT):
		direction.y -= 1
	
	direction = direction.normalized()
	
	# Move without collision detection
	if direction != Vector3.ZERO:
		position += direction * FLY_SPEED * delta

func normal_movement(delta: float):
	"""Normal walking movement with gravity and collision"""
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction using WASD
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	# Calculate movement direction relative to where player is looking
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
