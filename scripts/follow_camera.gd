extends Node3D

## Third-person 2.5D camera: gameplay stays on XZ, pitch remains fixed at 45 degrees.
@export_range(1.0, 20.0) var distance := 9.0
@export_range(0.5, 5.0) var height := 1.0
## Degrees per horizontal mouse pixel. Vertical mouse movement is ignored.
@export_range(0.01, 1.0) var mouse_sensitivity := 0.15
var target: Buffalo
var yaw := 0.0
var gameplay_enabled := true
var shake_elapsed := 1.0
var shake_duration := 0.0
var shake_strength := 0.0
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	process_physics_priority = 10
	camera.current = true
	distance = GameBalance.get_number("camera_distance", distance)
	mouse_sensitivity = SessionState.get_mouse_sensitivity()
	camera.fov = GameBalance.get_number("camera_fov_deg", camera.fov)


func setup(actor: Buffalo) -> void:
	arm.clear_excluded_objects()
	target = actor
	arm.add_excluded_object(actor.get_rid())
	# Start behind the player once; never recenter on its heading afterwards.
	yaw = actor.global_rotation.y
	gameplay_enabled = true
	follow_target()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func horizontal_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func movement_direction(axis: Vector2) -> Vector3:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return (right * axis.x - horizontal_forward() * axis.y).limit_length()


func follow_target() -> void:
	if not is_instance_valid(target):
		return
	# Follow position only, independent of body heading and Visual animation.
	global_position = target.global_position + Vector3.UP * height
	if shake_elapsed < shake_duration and SessionState.camera_shake_enabled:
		var envelope := 1.0 - shake_elapsed / shake_duration
		var phase := shake_elapsed * GameBalance.get_number("camera_shake_frequency", 42.0)
		global_position += Vector3(
			sin(phase) * shake_strength * envelope,
			cos(phase * 1.31) * shake_strength * envelope * 0.45,
			sin(phase * 0.83) * shake_strength * envelope
		)
	global_rotation = Vector3(0.0, yaw, 0.0)
	arm.position = Vector3.ZERO
	arm.rotation = Vector3(-GameBalance.get_angle("camera_pitch_deg", 45.0), 0.0, 0.0)
	arm.spring_length = distance


func _physics_process(delta: float) -> void:
	shake_elapsed += delta
	follow_target()


func trigger_shake(event_name: StringName) -> void:
	if not SessionState.camera_shake_enabled:
		return
	if event_name not in [&"HORN_HIT", &"DASH_HIT", &"CLASH_START", &"CLASH_BREAK"]:
		return
	shake_elapsed = 0.0
	shake_duration = GameBalance.get_number("camera_shake_duration_s", 0.12)
	shake_strength = GameBalance.get_number("camera_shake_distance", 0.06)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Not handled: MatchController._input must still see Esc to toggle pause.
		var controller := get_parent() as MatchController
		if controller == null or controller.phase != &"PLAYING":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw - deg_to_rad(event.relative.x * mouse_sensitivity), -PI, PI)
		follow_target()
		get_viewport().set_input_as_handled()


func end_gameplay() -> void:
	gameplay_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
