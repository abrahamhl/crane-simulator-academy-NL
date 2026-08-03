extends CharacterBody3D
## PlayerController — first-person on-foot movement with real collision.
## Mouse look updates yaw (rotates the body) and pitch (exposed for the camera
## director, which owns the actual Camera3D). Movement is disabled while the
## player is riding the ladder or seated in the cabin (see MachineAccess).

var pitch := 0.0
var move_enabled := true

var _yaw := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = AppSettings.PLAYER_RADIUS
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.85, 0.0)
	add_child(shape)
	up_direction = Vector3.UP


func _unhandled_input(event: InputEvent) -> void:
	if not move_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * AppSettings.MOUSE_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * AppSettings.MOUSE_SENSITIVITY,
			deg_to_rad(-AppSettings.PITCH_LIMIT_DEG), deg_to_rad(AppSettings.PITCH_LIMIT_DEG))
		rotation.y = _yaw


## Injects a look delta directly (used by the headless self-test, which has no
## real mouse motion events to dispatch).
func apply_look_delta(dx: float, dy: float) -> void:
	_yaw -= dx * AppSettings.MOUSE_SENSITIVITY
	pitch = clampf(pitch - dy * AppSettings.MOUSE_SENSITIVITY,
		deg_to_rad(-AppSettings.PITCH_LIMIT_DEG), deg_to_rad(AppSettings.PITCH_LIMIT_DEG))
	rotation.y = _yaw


func physics_step(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= AppSettings.PLAYER_GRAVITY * delta
	if not move_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"))
	var speed := AppSettings.PLAYER_SPRINT_SPEED if Input.is_action_pressed("fine_mode") \
		else AppSettings.PLAYER_WALK_SPEED
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = AppSettings.PLAYER_JUMP_VELOCITY

	move_and_slide()


## Turns the body to face a world point. Used by the demo pilot so the
## attract-loop footage shows the operator actually walking to the control
## station rather than teleporting onto it.
func look_at_target(target: Vector3) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	_yaw = atan2(-to.x, -to.z)
	rotation.y = _yaw


## One step of walking straight ahead, bypassing the input map. Kept separate
## from physics_step() so nothing about normal player movement changes.
func drive_forward(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= AppSettings.PLAYER_GRAVITY * delta
	var dir := -global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * AppSettings.PLAYER_WALK_SPEED
	velocity.z = dir.z * AppSettings.PLAYER_WALK_SPEED
	move_and_slide()


## Eye position + look rotation (yaw from the body, pitch layered on top),
## used by CameraDirector for the walk-view first-person camera.
func eye_transform() -> Transform3D:
	var right_axis := global_transform.basis.x.normalized()
	var basis := global_transform.basis.rotated(right_axis, pitch)
	var origin := global_position + Vector3(0.0, AppSettings.PLAYER_EYE_HEIGHT, 0.0)
	return Transform3D(basis, origin)
