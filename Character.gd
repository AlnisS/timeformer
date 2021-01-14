extends KinematicBody

const MOUSE_SENSITIVITY := 0.002
const SNEAK_SPEED := 1.295
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
	_handle_horizontal_motion(delta, _modify_move_input( _get_move_input()))
	_handle_vertical_motion(delta)
	_clip_horizontal_velocity(delta, start_xz)
	
	# I keep finding myself rewriting this line, so it stays as a comment
	# print(Vector2(velocity.x, velocity.z).length())

# returns character to start (don't call this in the middle of a loop, it will break stuff!)
func _reset() -> void:
	velocity = Vector3.ZERO
	transform = original_transform
	motion_state = MotionState.WALK

# janky stopgap  function to control rate of flow of time
func _get_time_factor() -> float:
	return lerp(time_factor, \
		BULLET_TIME if Input.is_action_pressed("main_button") else REGULAR_TIME, \
		0.15)

# collects raw input from the user
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

# transforms user input into direction/magnitude of horizontal
func _modify_move_input(move_input: Vector2) -> Vector2:
	if Input.is_action_pressed("sneak"):
		motion_state = MotionState.SNEAK
	elif (Input.is_action_pressed("sprint") \
			|| (motion_state == MotionState.SPRINT)) && move_input.y < 0:
			# this approach causes a delay when starting a sprint from a standstill:
			# && Vector2(velocity.x, velocity.y).length() > 1:
		motion_state = MotionState.SPRINT
	else:
		motion_state = MotionState.WALK
	
	match motion_state:
		MotionState.WALK:
			$Camera.fov = lerp($Camera.fov, 70, 0.2)
			$Camera.translation.y = lerp($Camera.translation.y, 1.62, 0.3)
		MotionState.SNEAK:
			move_input *= (SNEAK_SPEED / WALK_SPEED)
			$Camera.fov = lerp($Camera.fov, 70, 0.2)
			$Camera.translation.y = lerp($Camera.translation.y, 1.45, 0.3)
		MotionState.SPRINT:
			if move_input.y < 0:
				move_input.y *= (SPRINT_SPEED / WALK_SPEED)
				$Camera.fov = lerp($Camera.fov, 85, 0.2)
				$Camera.translation.y = lerp($Camera.translation.y, 1.62, 0.3)
	
	return move_input.rotated(-$Camera.rotation.y) * WALK_SPEED

# runs physics for horizontal movement
func _handle_horizontal_motion(delta: float, move_input: Vector2) -> void:
	var initially_on_ground = _is_on_ground()
	if initially_on_ground:
		velocity -= Vector3(velocity.x, 0, velocity.z) * delta * REGULAR_ACCEL_FACTOR
		velocity += Vector3(move_input.x, 0, move_input.y) * delta * REGULAR_ACCEL_FACTOR
	else:
		velocity -= Vector3(velocity.x, 0, velocity.z) * delta * AIR_ACCEL_FACTOR
		velocity += Vector3(move_input.x, 0, move_input.y) * delta * AIR_ACCEL_FACTOR
		
		# note: revisit this when joysticks are supported
		if (move_input.length_squared() == 0):
			velocity -= Vector3(velocity.x, 0, velocity.z) * delta * EXTRA_AIR_BRAKE_FACTOR
	
	var tmp_transform = transform
	
	var _walk_collision = move_and_collide(Vector3(velocity.x, 0, velocity.z) * delta)
	
#	print(initially_on_ground, _is_on_ground())
	
	if motion_state == MotionState.SNEAK and initially_on_ground and not _is_on_ground():
		print("fall off")
		transform = tmp_transform
		_walk_collision = move_and_collide(Vector3(0, 0, velocity.z) * delta)
		if not _is_on_ground():
			transform = tmp_transform
			_walk_collision = move_and_collide(Vector3(velocity.x, 0, 0) * delta)
			if not _is_on_ground():
				transform = tmp_transform

# runs physics for vertical movement
func _handle_vertical_motion(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	
	if _is_on_ground() and Input.is_action_pressed("jump") and velocity.y <= 0:
		velocity.y = JUMP_VELOCITY
	
	if _is_on_ground() and velocity.y <= 0:
		velocity.y = 0
		return
	
	# -0.2 in horizontal motion is to prevent walls from causing weirdness
	var init_pos = Vector2(transform.origin.x, transform.origin.z)
	
	var vertical_collision = \
		move_and_collide(Vector3(-0.2 * velocity.x, velocity.y, -0.2 * velocity.z) * delta)
	
	if vertical_collision != null:
		velocity.y = 0
		translation.x -= vertical_collision.remainder.x * delta
		translation.z -= vertical_collision.remainder.z * delta
	
	translation.x += velocity.x * 0.2 * delta
	translation.z += velocity.z * 0.2 * delta
	
	var final_pos = Vector2(transform.origin.x, transform.origin.z)
	var delta_pos = final_pos - init_pos
	
#	if (!final_pos.is_equal_approx(init_pos)):
#		print()
#		print(init_pos)
#		print(final_pos)
#		print(delta_pos)
#		translate(Vector3(delta_pos.x, 0, delta_pos.y) * -2)
#		move_and_collide(Vector3(0, 0, 0))
	
	

# clips stored velocity to actual velocity over this loop cycle
func _clip_horizontal_velocity(delta: float, start_xz: Vector2) -> void:
	velocity.x = (translation.x - start_xz.x) / delta
	velocity.z = (translation.z - start_xz.y) / delta

# checks whether the character is on a floor - TODO: still kinda buggy and janky
func _is_on_ground() -> bool:
	
	var tmp_transform = transform
	var tmp_safe_margin = get_safe_margin()
	set_safe_margin(tmp_safe_margin * 3)
	var tmp_collision = move_and_collide(Vector3.ZERO)
	if tmp_collision != null:
		translate(tmp_collision.remainder)
	set_safe_margin(tmp_safe_margin)
	var result = !test_move(transform, Vector3(0, get_safe_margin() * 3, 0)) and test_move(transform, Vector3(0, -get_safe_margin() * 3, 0))
#	print(transform.basis.y)
	transform = tmp_transform
	return result

#	return !test_move(transform, Vector3(fudge.x * -delta, 0.001, fudge.y * -delta)) \
#		and test_move(transform, Vector3(fudge.x * -delta, -0.001, fudge.y * -delta))

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
