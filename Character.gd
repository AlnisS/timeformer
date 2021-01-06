extends KinematicBody

const mouse_sensitivity := 0.002
const WALK_SPEED := 4.317
const SPRINT_SPEED := 5.612
const STEP_UP_DISTANCE = 0.55
const GRAVITY = 31.36
const JUMP_VELOCITY = 8.5
const REGULAR_BRAKE_FACTOR = 25
const REGULAR_ACCEL_FACTOR = 25
const AIR_BRAKE_FACTOR = 2
const AIR_ACCEL_FACTOR = 2
const EXTRA_AIR_BRAKE_FACTOR = 2

onready var original_transform = transform

var velocity = Vector3.ZERO

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if Input.is_action_just_pressed("reset"):
		velocity = Vector3.ZERO
		transform = original_transform
	
	var start_x = translation.x
	var start_z = translation.z
	
	var move_input: Vector2 = Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		move_input += Vector2.UP
	if Input.is_action_pressed("move_backward"):
		move_input += Vector2.DOWN
	if Input.is_action_pressed("move_left"):
		move_input += Vector2.LEFT
	if Input.is_action_pressed("move_right"):
		move_input += Vector2.RIGHT
	
	var move_input_mag = move_input.length()
	
	# this is a bit weird having WALK_SPEED and all, but basically WALK_SPEED
	# was a decent speed when moving around at constant velocity,
	# and this was derived from that code, so it will be refactored out soon
	move_input = move_input.normalized().rotated(-$Camera.rotation.y) * WALK_SPEED
	
	if Input.is_action_pressed("sneak"):
		move_input *= 0.25
	
	if _is_on_ground(delta):
		velocity.x -= velocity.x * delta * REGULAR_BRAKE_FACTOR
		velocity.z -= velocity.z * delta * REGULAR_BRAKE_FACTOR

		velocity.x += move_input.x * delta * REGULAR_ACCEL_FACTOR
		velocity.z += move_input.y * delta * REGULAR_ACCEL_FACTOR
	else:
		velocity.x -= velocity.x * delta * AIR_BRAKE_FACTOR
		velocity.z -= velocity.z * delta * AIR_BRAKE_FACTOR
		
		velocity.x += move_input.x * delta * AIR_ACCEL_FACTOR
		velocity.z += move_input.y * delta * AIR_ACCEL_FACTOR
		
		if (move_input_mag < 0.001):
			velocity.x -= velocity.x * delta * EXTRA_AIR_BRAKE_FACTOR
			velocity.z -= velocity.z * delta * EXTRA_AIR_BRAKE_FACTOR

	
	
#	print(velocity.z)
	
#	velocity.x = move_input.x
#	velocity.z = move_input.y
	
	var walk_collision = move_and_collide(Vector3(velocity.x, 0, velocity.z) * delta)
	
	if _is_on_ground(delta):
		velocity.y = 0
	else:
		velocity.y -= GRAVITY * delta
	
	if _is_on_ground(delta) and Input.is_action_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		
#	var gravity_collision = move_and_collide(Vector3(0, velocity.y, 0) * delta)
	var gravity_collision = move_and_collide(Vector3(-0.2 * velocity.x, velocity.y, -0.2 * velocity.z) * delta)
	
	if gravity_collision != null:
		velocity.y = 0
		translation.x += (0.2 * velocity.x - gravity_collision.remainder.x) * delta
		translation.z += (0.2 * velocity.z - gravity_collision.remainder.z) * delta
	else:
		translation.x += velocity.x * 0.2 * delta
		translation.z += velocity.z * 0.2 * delta
	
	velocity.x = (translation.x - start_x) / delta
	velocity.z = (translation.z - start_z) / delta
#
#	print(sqrt(pow(velocity.x, 2) + pow(velocity.z, 2)))
	
#	print(transform.origin.y)

#	print(_is_on_ground(delta))
	
	
#	if collision != null:
#		pass
#		print(collision.remainder)
#		var step_up_collision = move_and_collide(collision.remainder + Vector3.UP * STEP_UP_DISTANCE, true, true, true)
#		if (step_up_collision == null):
#			transform.origin += collision.remainder + Vector3.UP * STEP_UP_DISTANCE
#			move_and_collide(Vector3.DOWN)
	
#	move_and_slide(Vector3(move_input.x, 0, move_input.y), Vector3.UP)
	
	

func _is_on_ground(delta: float) -> bool:
	return move_and_collide(Vector3(velocity.x * -delta, 0.001, velocity.z * -delta), true, true, true) == null \
		and move_and_collide(Vector3(velocity.x * -delta, -0.001, velocity.z * -delta), true, true, true) != null \
#		and abs(velocity.y) <= 0.001

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("main_button"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_tree().set_input_as_handled()

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		$Camera.rotation.y -= event.relative.x * mouse_sensitivity
		$Camera.rotation.x -= event.relative.y * mouse_sensitivity
		$Camera.rotation.x = clamp($Camera.rotation.x, -PI / 2, PI / 2)
