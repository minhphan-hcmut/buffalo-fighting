extends Node3D

## Third-person 2.5D camera: gameplay stays on XZ. A low, fixed pitch over the buffalo's
## chosen shoulder (camera_pitch_deg, camera_shoulder_offset) so the player sees both
## buffaloes' heads and horns; the mouse only turns yaw. Hits give a short punch
## (push in + narrower FOV) and shake. Presentation only: never changes match state.
@export_range(1.0, 20.0) var distance := 9.0
@export_range(0.5, 5.0) var height := 1.0
## Degrees per horizontal mouse pixel. Vertical mouse movement is ignored.
@export_range(0.01, 1.0) var mouse_sensitivity := 0.15
var target: Buffalo
var yaw := 0.0
var gameplay_enabled := true
var _pitch := 0.0
var _shoulder := 0.0
var _fov := 0.0
var shake_elapsed := 1.0
var shake_duration := 0.0
var shake_strength := 0.0
var clash_zoom_active := false
var clash_zoom_weight := 0.0
## Seconds since the last hit punch started, and how strong it is (1 = normal hit).
var punch_time := 1.0
var punch_strength := 0.0
## Seconds since the RESULT overview started, or -1 while following the buffalo.
var overview_time := -1.0
var _overview_from := Vector3.ZERO
var _overview_yaw_from := 0.0
var _overview_yaw_to := 0.0
## Seconds since the result's winner shot started, or -1. Set by show_winner().
var winner_time := -1.0
var _winner: Node3D
var _winner_from_position := Vector3.ZERO
var _winner_from_yaw := 0.0
var _winner_from_pitch := 0.0
var _winner_from_length := 0.0
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	process_physics_priority = 10
	camera.current = true
	_update_framing(1.0)
	mouse_sensitivity = SessionState.get_mouse_sensitivity()
	camera.fov = _fov


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
	return YawBasis.forward(yaw)


func movement_direction(axis: Vector2) -> Vector3:
	var right := YawBasis.right(yaw)
	return (right * axis.x - horizontal_forward() * axis.y).limit_length()


## RESULT: rise from the buffalo to a high view of the whole arena. The view looks across the
## arena from the long side nearest the current view, so both gates (on the X axis) stay in frame.
func show_overview() -> void:
	if overview_time >= 0.0:
		return
	overview_time = 0.0
	_overview_from = global_position
	_overview_yaw_from = yaw
	_overview_yaw_to = 0.0 if absf(angle_difference(yaw, 0.0)) <= PI * 0.5 else PI
	gameplay_enabled = false
	# High above both buffaloes and the fence: nothing for the arm to collide with.
	arm.collision_mask = 0


## World position the camera ends at in the overview.
func overview_camera_position() -> Vector3:
	var pitch := GameBalance.get_angle("result_camera_pitch_deg", 60.0)
	var length := GameBalance.get_number("result_camera_distance", 22.0)
	return Vector3.UP * (height + length * sin(pitch)) - YawBasis.forward(_overview_yaw_to) * length * cos(pitch)


func _follow_overview() -> void:
	var blend := GameBalance.get_number("result_camera_blend_s", 1.2)
	var weight := 1.0 if blend <= 0.0 else smoothstep(0.0, 1.0, overview_time / blend)
	global_position = _overview_from.lerp(Vector3.UP * height, weight)
	yaw = lerp_angle(_overview_yaw_from, _overview_yaw_to, weight)
	global_rotation = Vector3(0.0, yaw, 0.0)
	arm.position = Vector3.RIGHT * _shoulder * (1.0 - weight)
	var pitch := lerpf(_pitch, GameBalance.get_angle("result_camera_pitch_deg", 60.0), weight)
	arm.rotation = Vector3(-pitch, 0.0, 0.0)
	arm.spring_length = lerpf(distance, GameBalance.get_number("result_camera_distance", 22.0), weight)
	_keep_inside_arena()


## Result screen: after the outro, glide from the overview down to a slow orbit
## around the winner, seen from the front three-quarter, framed right of the result
## panel. Idempotent.
func show_winner(actor: Node3D) -> void:
	if winner_time >= 0.0 or actor == null:
		return
	winner_time = 0.0
	_winner = actor
	_winner_from_position = global_position
	_winner_from_yaw = yaw
	_winner_from_pitch = -arm.rotation.x
	_winner_from_length = arm.spring_length
	gameplay_enabled = false
	arm.collision_mask = 0


func _follow_winner() -> void:
	var blend := GameBalance.get_number("result_winner_blend_s")
	var weight := 1.0 if blend <= 0.0 else smoothstep(0.0, 1.0, winner_time / blend)
	var focus := _winner.global_position + Vector3.UP * GameBalance.get_number("result_winner_look_height")
	# The camera sits behind `yaw`, so face the winner by looking from its front.
	var side := 1.0 if SessionState.camera_side == 0 else -1.0
	var orbit_yaw := _winner.global_rotation.y + PI + side * deg_to_rad(GameBalance.get_number("result_winner_angle_deg") + GameBalance.get_number("result_winner_orbit_deg_s") * winner_time)
	global_position = _winner_from_position.lerp(focus, weight)
	yaw = lerp_angle(_winner_from_yaw, orbit_yaw, weight)
	global_rotation = Vector3(0.0, yaw, 0.0)
	arm.position = Vector3.ZERO
	arm.rotation = Vector3(-lerpf(_winner_from_pitch, GameBalance.get_angle("result_winner_pitch_deg"), weight), 0.0, 0.0)
	arm.spring_length = lerpf(_winner_from_length, GameBalance.get_number("result_winner_distance"), weight)
	camera.h_offset = GameBalance.get_number("result_winner_h_offset") * weight
	_keep_inside_arena()


func follow_target() -> void:
	if winner_time >= 0.0:
		_follow_winner()
		return
	if overview_time >= 0.0:
		_follow_overview()
		return
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
	arm.position = Vector3.RIGHT * _shoulder
	arm.rotation = Vector3(-_pitch, 0.0, 0.0)
	arm.spring_length = distance - punch_weight() * GameBalance.get_number("camera_punch_push")
	_keep_inside_arena()


func _update_framing(weight: float) -> void:
	var suffix: String = ["_near", "", "_far"][SessionState.camera_view]
	distance = lerpf(distance, GameBalance.get_number("camera_distance" + suffix, GameBalance.get_number("camera_distance")), weight)
	height = lerpf(height, GameBalance.get_number("camera_look_height" + suffix, GameBalance.get_number("camera_look_height")), weight)
	_pitch = lerpf(_pitch, deg_to_rad(GameBalance.get_number("camera_pitch_deg" + suffix, GameBalance.get_number("camera_pitch_deg"))), weight)
	_fov = lerpf(_fov, GameBalance.get_number("camera_fov_deg" + suffix, GameBalance.get_number("camera_fov_deg")), weight)
	var side := 1.0 if SessionState.camera_side == 0 else -1.0
	_shoulder = lerpf(_shoulder, side * GameBalance.get_number("camera_shoulder_offset"), weight)


func _keep_inside_arena() -> void:
	# Gate leaves have no collision; keep the lens inside the oval even through a gate gap.
	var margin := GameBalance.get_number("camera_bounds_margin_m")
	var half := Vector2(GameBalance.get_number("arena_rx"), GameBalance.get_number("arena_rz")) - Vector2.ONE * margin
	if _lens_inside(half):
		return
	if overview_time < 0.0 and winner_time < 0.0:
		# Pull the lens in along the arm first (the GDD pitch stays, the camera keeps looking at
		# the buffalo, as the old fence-colliding spring arm did); only when the arm is down to
		# its shortest, crane up. Either way the lens never leaves the oval, even at a gate gap.
		var shortest := minf(arm.spring_length, GameBalance.get_number("camera_bounds_min_length_m"))
		var full := arm.spring_length
		arm.spring_length = shortest
		if _lens_inside(half):
			_bisect(full, shortest, func(value: float) -> void: arm.spring_length = value, half)
			return
		var low := -arm.rotation.x
		var high := maxf(low, deg_to_rad(GameBalance.get_number("camera_bounds_max_pitch_deg")))
		arm.rotation.x = -high
		if _lens_inside(half):
			_bisect(low, high, func(value: float) -> void: arm.rotation.x = -value, half)
			return
	# Result shots (and a lens still outside): move the pivot in until the lens is inside.
	var lens := _lens()
	var scaled := Vector2(lens.x / half.x, lens.z / half.y)
	var inside := scaled.normalized() * half
	global_position += Vector3(inside.x - lens.x, 0.0, inside.y - lens.z)


# Smallest change from `from` toward `to` (10 halvings) that puts the lens inside; `apply`
# sets the value being searched. Returns that value, already applied.
func _bisect(from: float, to: float, apply: Callable, half: Vector2) -> float:
	var outside := from
	var inside := to
	for step in 10:
		var middle := (outside + inside) * 0.5
		apply.call(middle)
		if _lens_inside(half):
			inside = middle
		else:
			outside = middle
	apply.call(inside)
	return inside


func _lens() -> Vector3:
	return arm.global_position + arm.global_basis.z * arm.spring_length


func _lens_inside(half: Vector2) -> bool:
	var lens := _lens()
	return Vector2(lens.x / half.x, lens.z / half.y).length() <= 1.0


func _physics_process(delta: float) -> void:
	shake_elapsed += delta
	if overview_time >= 0.0:
		overview_time += delta
	if winner_time >= 0.0:
		winner_time += delta
	follow_target()


func set_clash_zoom(active: bool) -> void:
	clash_zoom_active = active


func _process(delta: float) -> void:
	_update_framing(1.0 - exp(-delta / GameBalance.get_number("camera_settings_blend_s")))
	var blend := GameBalance.get_number("vfx_clash_zoom_blend_s", 0.15)
	clash_zoom_weight = move_toward(clash_zoom_weight, 1.0 if clash_zoom_active and overview_time < 0.0 else 0.0, delta / maxf(0.001, blend))
	punch_time += delta
	camera.fov = _fov - clash_zoom_weight * GameBalance.get_number("vfx_clash_zoom_deg", 5.0) - punch_weight() * GameBalance.get_number("camera_punch_fov_deg")


## Current punch amount: `punch_strength` at the hit, easing out to 0 over camera_punch_s.
## Runs on real time, so the punch plays through hitstop.
func punch_weight() -> float:
	var duration := GameBalance.get_number("camera_punch_s")
	if not SessionState.camera_punch_enabled or duration <= 0.0 or punch_time >= duration or overview_time >= 0.0:
		return 0.0
	var remaining := 1.0 - punch_time / duration
	return punch_strength * remaining * remaining


func trigger_shake(event_name: StringName) -> void:
	if SessionState.camera_punch_enabled and event_name in [&"HORN_HIT", &"DASH_HIT", &"COUNTER_HIT"]:
		punch_time = 0.0
		punch_strength = GameBalance.get_number("camera_punch_heavy_scale") if event_name != &"HORN_HIT" else 1.0
	if not SessionState.camera_shake_enabled:
		return
	if event_name not in [&"HORN_HIT", &"DASH_HIT", &"COUNTER_HIT", &"PARRY_SUCCESS", &"CLASH_START"]:
		return
	shake_elapsed = 0.0
	shake_duration = GameBalance.get_number("camera_shake_duration_s", 0.12)
	shake_strength = GameBalance.get_number("camera_shake_distance", 0.06)
	if event_name != &"HORN_HIT":
		shake_strength *= GameBalance.get_number("camera_shake_heavy_scale")
		shake_duration *= GameBalance.get_number("camera_shake_heavy_duration_scale")


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
