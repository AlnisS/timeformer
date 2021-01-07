extends KinematicBody

const MOUSE_SENSITIVITY := 0.002
const WALK_SPEED := 4.317
const SPRINT_SPEED := 5.612
const STEP_UP_DISTANCE = 0.55
const GRAVITY = 31.36
const JUMP_VELOCITY = 8.6
const REGULAR_ACCEL_FACTOR = 12
const AIR_ACCEL_FACTOR = 2
const EXTRA_AIR_BRAKE_FACTOR = 2
const REGULAR_TIME = 1.0
const BULLET_TIME = 0.05

enum MotionState {WALK, SPRINT, SNEAK}

onready var original_transform = transform

var time_factor = REGULAR_TIME
var velocity = Vector3.ZERO
var motion_state = MotionState.WALK

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if Input.is_action_just_pressed("reset"):
		_reset()
	
	time_factor = _get_time_factor()
	delta *= time_factor
	
	var start_xz = Vector2(translation.x, translation.z)
	
	var move_input: Vector2 = _get_move_input()
	move_input = _modify_move_input(move_input)
	_handle_horizontal_motion(delta, move_input)
	_handle_vertical_motion(delta)
	
	# clip velocity to actual velocity after collisions
	velocity.x = (translation.x - start_xz.x) / delta
	velocity.z = (translation.z - start_xz.y) / delta
	
#	print(Vector2(velocity.x, velocity.z).length())

func _reset() -> void:
	velocity = Vector3.ZERO
	transform = original_transform
	motion_state = MotionState.WALK

func _get_time_factor() -> float:
	return lerp(time_factor, \
		BULLET_TIME if Input.is_action_pressed("main_button") else REGULAR_TIME, \
		0.15)

func _get_move_input() -> Vector2:
	var move_input: Vector2 = Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		move_input += Vector2.UP
	if Input.is_action_pressed("move_backward"):
		move_input += Vector2.DOWN
	if Input.is_action_pressed("move_left"):
		move_input += Vector2.LEFT
	if Input.is_action_pressed("move_right"):
		move_input += Vector2.RIGHT
	
	return move_input.normalized()

# moves character up and down slightly at xz of last frame and checks collision
func _is_on_ground(delta: float) -> bool:
	return !test_move(transform, Vector3(velocity.x * -delta, 0.001, velocity.z * -delta)) \
		and test_move(transform, Vector3(velocity.x * -delta, -0.001, velocity.z * -delta))

func _modify_move_input(move_input: Vector2) -> Vector2:
	motion_state = MotionState.WALK
	if Input.is_action_pressed("sneak"):
		motion_state = MotionState.SNEAK
	if Input.is_action_pressed("sprint"):
		motion_state = MotionState.SPRINT
	
	match motion_state:
		MotionState.WALK:
			$Camera.fov = lerp($Camera.fov, 70, 0.2)
		MotionState.SNEAK:
			move_input *= 0.3
			$Camera.fov = lerp($Camera.fov, 70, 0.2)
		MotionState.SPRINT:
			if move_input.y < 0:
				move_input.y *= 1.3
				$Camera.fov = lerp($Camera.fov, 85, 0.2)
	
	move_input = move_input.rotated(-$Camera.rotation.y) * WALK_SPEED
	return move_input

func _handle_horizontal_motion(delta: float, move_input: Vector2) -> void:
	# TODO: this _is_on_ground is not stable
	if _is_on_ground(delta):
		velocity -= Vector3(velocity.x, 0, velocity.z) * delta * REGULAR_ACCEL_FACTOR
		velocity += Vector3(move_input.x, 0, move_input.y) * delta * REGULAR_ACCEL_FACTOR
	else:
		velocity -= Vector3(velocity.x, 0, velocity.z) * delta * AIR_ACCEL_FACTOR
		velocity += Vector3(move_input.x, 0, move_input.y) * delta * AIR_ACCEL_FACTOR
		
		# note: revisit this when joysticks are supported
		if (move_input.length_squared() == 0):
			velocity -= Vector3(velocity.x, 0, velocity.z) * delta * EXTRA_AIR_BRAKE_FACTOR
	
	var walk_collision = move_and_collide(Vector3(velocity.x, 0, velocity.z) * delta)

func _handle_vertical_motion(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	
	if _is_on_ground(delta) and Input.is_action_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	
	# -0.2 in horizontal motion is to prevent walls from causing weirdness
	var vertical_collision = move_and_collide(Vector3(-0.2 * velocity.x, velocity.y, -0.2 * velocity.z) * delta)
	
	if vertical_collision != null:
		velocity.y = 0
		translation.x -= vertical_collision.remainder.x * delta
		translation.z -= vertical_collision.remainder.z * delta
	
	translation.x += velocity.x * 0.2 * delta
	translation.z += velocity.z * 0.2 * delta

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("main_button"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_tree().set_input_as_handled()

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		$Camera.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		$Camera.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		$Camera.rotation.x = clamp($Camera.rotation.x, -PI / 2, PI / 2)
