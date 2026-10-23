class_name BuffaloAnimator
extends Node3D

# Visual-only procedural motion for the unrigged buffalo model (animation stage A).
# Moves this node plus the ear/tail pivots it creates; the physics body is never touched,
# so gameplay, LAN and combat tests are unaffected. Motion is read from the body's actual
# displacement, which also works on a LAN client where velocity is not replicated.

const POSE_RATE := 12.0
const SNAP_RATE := 32.0
const MOTION_FILTER_RATE := 12.0
const TELEPORT_DISTANCE := 3.0
const GAIT_HZ_MIN := 1.1
const GAIT_HZ_MAX := 2.4
const BOB_HEIGHT := 0.05
const SWAY_ROLL_DEG := 2.5
const ROCK_PITCH_DEG := 1.5
const ACCEL_PITCH_DEG_PER_MS2 := 0.12
const ACCEL_PITCH_MAX_DEG := 6.0
const TURN_ROLL_DEG_PER_RAD_S := 1.2
const TURN_ROLL_MAX_DEG := 8.0
const BREATH_HZ := 0.35
const BREATH_SCALE := 0.012
const VICTORY_HOP_HEIGHT := 0.22
const VICTORY_HOP_HZ := 1.2
# Rear hooves: the head dips while the hind feet stay planted.
const PITCH_PIVOT := Vector3(0.0, 0.0, 1.17)
# Measured from buffalo.glb: inner (root) end of the left/right ears, top of the tail.
const EAR_PIVOT := Vector3(0.36, 1.47, -1.19)
const TAIL_PIVOT := Vector3(0.0, 1.42, 1.52)

var buffalo: Buffalo
var controller: MatchController
var speed := 0.0
var forward_speed := 0.0
var forward_accel := 0.0
var turn_rate := 0.0
var gait_phase := 0.0
var time := 0.0
var pose_offset := Vector3.ZERO
var pose_pitch := 0.0
var pose_roll := 0.0
var ear_back := 0.0
var tail_lift := 0.0
var victory_weight := 0.0
var defeat_weight := 0.0
var ear_pivots: Array[Node3D] = []
var tail_pivot: Node3D
var ear_flick_time := 0.0
var ear_flick_side := 0
var next_ear_flick := 2.0
var rng := RandomNumberGenerator.new()

var _target_offset := Vector3.ZERO
var _target_pitch := 0.0
var _target_roll := 0.0
var _target_rate := POSE_RATE
var _target_ear_back := 0.0
var _target_tail_lift := 0.0
var _gait_weight := 1.0
var _shake_roll := 0.0
var _last_position := Vector3.ZERO
var _last_yaw := 0.0


func _ready() -> void:
	buffalo = get_parent() as Buffalo
	var node := get_parent()
	while node != null and not node is MatchController:
		node = node.get_parent()
	controller = node as MatchController
	rng.seed = get_instance_id()
	_build_pivots()
	reset_motion()


func _physics_process(delta: float) -> void:
	if _is_paused():
		return
	sample_motion(delta)


func _process(delta: float) -> void:
	if _is_paused():
		return
	update_pose(delta)


func reset_motion() -> void:
	if buffalo == null:
		return
	_last_position = buffalo.global_position
	_last_yaw = buffalo.global_rotation.y
	speed = 0.0
	forward_speed = 0.0
	forward_accel = 0.0
	turn_rate = 0.0


# Samples the body's displacement once per physics tick, when its position actually changes.
func sample_motion(delta: float) -> void:
	if buffalo == null or delta <= 0.0:
		return
	var position := buffalo.global_position
	var step := Vector3(position.x - _last_position.x, 0.0, position.z - _last_position.z)
	if step.length() > TELEPORT_DISTANCE:
		reset_motion()
		return
	var planar := step / delta
	var heading := -buffalo.global_basis.z
	heading.y = 0.0
	heading = heading.normalized()
	var filter := 1.0 - exp(-MOTION_FILTER_RATE * delta)
	speed = lerpf(speed, planar.length(), filter)
	var filtered_forward := lerpf(forward_speed, planar.dot(heading), filter)
	forward_accel = lerpf(forward_accel, (filtered_forward - forward_speed) / delta, filter)
	forward_speed = filtered_forward
	var yaw := buffalo.global_rotation.y
	turn_rate = lerpf(turn_rate, angle_difference(_last_yaw, yaw) / delta, filter)
	_last_position = position
	_last_yaw = yaw


func update_pose(delta: float) -> void:
	if buffalo == null or delta <= 0.0:
		return
	time += delta
	_compute_targets()
	var k := 1.0 - exp(-_target_rate * delta)
	pose_offset = pose_offset.lerp(_target_offset, k)
	pose_pitch = lerpf(pose_pitch, _target_pitch, k)
	pose_roll = lerpf(pose_roll, _target_roll, k)
	var soft := 1.0 - exp(-POSE_RATE * delta)
	ear_back = lerpf(ear_back, _target_ear_back, soft)
	tail_lift = lerpf(tail_lift, _target_tail_lift, soft)
	var result := _result_for_self()
	victory_weight = lerpf(victory_weight, 1.0 if result > 0 else 0.0, soft * 0.5)
	defeat_weight = lerpf(defeat_weight, 1.0 if result < 0 else 0.0, soft * 0.5)

	var walk_speed := GameBalance.get_number("walk_speed", 8.75)
	var speed_ratio := clampf(speed / walk_speed, 0.0, 1.0)
	gait_phase = fposmod(gait_phase + delta * lerpf(GAIT_HZ_MIN, GAIT_HZ_MAX, speed_ratio), 1.0)
	var walk := clampf(speed / walk_speed, 0.0, 1.3) * _gait_weight
	var bob := BOB_HEIGHT * walk * (0.5 - 0.5 * cos(gait_phase * TAU * 2.0))
	var hop := victory_weight * VICTORY_HOP_HEIGHT * absf(sin(time * TAU * VICTORY_HOP_HZ))

	var accel_pitch := clampf(-forward_accel * ACCEL_PITCH_DEG_PER_MS2, -ACCEL_PITCH_MAX_DEG, ACCEL_PITCH_MAX_DEG)
	var turn_roll := clampf(turn_rate * TURN_ROLL_DEG_PER_RAD_S, -TURN_ROLL_MAX_DEG, TURN_ROLL_MAX_DEG) * (0.4 + 0.6 * minf(walk, 1.0))
	var pitch := pose_pitch + deg_to_rad(
		accel_pitch
		+ walk * ROCK_PITCH_DEG * sin(gait_phase * TAU * 2.0 + 0.8)
		+ victory_weight * 6.0 * sin(time * TAU * VICTORY_HOP_HZ * 2.0)
		- defeat_weight * 8.0
	)
	var roll := pose_roll + deg_to_rad(turn_roll + walk * SWAY_ROLL_DEG * sin(gait_phase * TAU)) + _shake_roll
	var rotation_basis := Basis.from_euler(Vector3(pitch, 0.0, roll))
	var breath := 1.0 + BREATH_SCALE * sin(time * TAU * BREATH_HZ) * (1.0 - minf(walk, 1.0))
	var shaped := rotation_basis * Basis.from_scale(Vector3(1.0, breath, 1.0))
	var origin := PITCH_PIVOT - shaped * PITCH_PIVOT + pose_offset + Vector3(0.0, bob + hop, 0.0)
	transform = Transform3D(shaped, origin)
	_update_ears(delta, result)
	_update_tail(walk)


func _compute_targets() -> void:
	_target_offset = Vector3.ZERO
	_target_pitch = 0.0
	_target_roll = 0.0
	_target_rate = POSE_RATE
	_target_ear_back = 0.0
	_target_tail_lift = 0.0
	_gait_weight = 1.0
	_shake_roll = 0.0
	var progress := clampf(buffalo.state_time / buffalo.state_duration, 0.0, 1.0) if buffalo.state_duration > 0.0 else 0.0
	match buffalo.state:
		Buffalo.State.GUARD:
			_target_offset = Vector3(0.0, -0.04, 0.12)
			_target_pitch = deg_to_rad(-6.0)
			_target_ear_back = deg_to_rad(35.0)
		Buffalo.State.HORN_STARTUP:
			_target_offset = Vector3(0.0, -0.03, 0.15)
			_target_pitch = deg_to_rad(-10.0)
			_target_rate = SNAP_RATE
			_target_ear_back = deg_to_rad(30.0)
		Buffalo.State.HORN_ACTIVE:
			# Lunge, then toss the horns upward through the active window.
			_target_offset = Vector3(0.0, 0.0, -0.3)
			_target_pitch = deg_to_rad(lerpf(-16.0, 6.0, progress))
			_target_rate = SNAP_RATE * 1.3
			_target_ear_back = deg_to_rad(30.0)
		Buffalo.State.DASH_ACTIVE:
			_target_offset = Vector3(0.0, -0.04, -0.12)
			_target_pitch = deg_to_rad(-12.0)
			_target_rate = SNAP_RATE
			_target_ear_back = deg_to_rad(50.0)
			_target_tail_lift = deg_to_rad(55.0)
			_gait_weight = 1.4
		Buffalo.State.DASH_RECOVERY:
			_target_offset = Vector3(0.0, 0.0, 0.05)
			_target_pitch = deg_to_rad(4.0)
			_target_tail_lift = deg_to_rad(25.0)
		Buffalo.State.STUNNED:
			var fade := 1.0 - progress
			_target_offset = Vector3(0.0, 0.0, 0.12 * fade)
			_target_pitch = deg_to_rad(10.0 * fade)
			_target_rate = SNAP_RATE
			_target_tail_lift = deg_to_rad(20.0)
			_gait_weight = 0.0
			_shake_roll = deg_to_rad(4.0) * fade * sin(time * 38.0)
		Buffalo.State.CLASH:
			var winning := _clash_advantage()
			_target_offset = Vector3(0.0, -0.03, -0.2 * winning)
			_target_pitch = deg_to_rad(-12.0 - 3.0 * winning)
			_target_ear_back = deg_to_rad(45.0)
			_gait_weight = 0.0
			_shake_roll = deg_to_rad(1.5) * sin(time * 21.0)
		Buffalo.State.FLEE:
			_target_pitch = deg_to_rad(5.0)
			_target_tail_lift = deg_to_rad(35.0)
			_target_ear_back = deg_to_rad(40.0)
			_shake_roll = deg_to_rad(5.0) * sin(time * TAU * 3.0)


# +1 when this buffalo is winning the CLASH tug-of-war, -1 when losing.
func _clash_advantage() -> float:
	if controller == null or controller.active_clash.is_empty():
		return 0.0
	var balance := float(controller.active_clash.get("balance", 0.0)) / 100.0
	return clampf(balance if controller.active_clash.get("a") == buffalo else -balance, -1.0, 1.0)


# 1 = this buffalo won the match, -1 = lost, 0 = still playing or no winner.
func _result_for_self() -> int:
	if controller == null or not controller.finished or controller.winner_slot == 0:
		return 0
	if buffalo.state == Buffalo.State.FLEE:
		return 0
	return 1 if controller.winner_slot == buffalo.slot else -1


func _build_pivots() -> void:
	var model_root := get_node_or_null("Model/BuffaloRoot")
	if model_root == null:
		return
	for side in [-1, 1]:
		var label := "L" if side < 0 else "R"
		var pivot := Node3D.new()
		pivot.name = "EarPivot_" + label
		model_root.add_child(pivot)
		pivot.position = Vector3(EAR_PIVOT.x * side, EAR_PIVOT.y, EAR_PIVOT.z)
		for part in ["Ear_", "EarInner_"]:
			var mesh := model_root.get_node_or_null(part + label)
			if mesh != null:
				mesh.reparent(pivot)
		ear_pivots.append(pivot)
	tail_pivot = Node3D.new()
	tail_pivot.name = "TailPivot"
	model_root.add_child(tail_pivot)
	tail_pivot.position = TAIL_PIVOT
	for part in ["Tail", "TailTuft"]:
		var mesh := model_root.get_node_or_null(part)
		if mesh != null:
			mesh.reparent(tail_pivot)


func _update_ears(delta: float, result: int) -> void:
	if ear_pivots.size() != 2:
		return
	var idle := buffalo.state == Buffalo.State.NORMAL and result == 0
	if idle:
		next_ear_flick -= delta
		if next_ear_flick <= 0.0:
			next_ear_flick = rng.randf_range(2.0, 5.0)
			ear_flick_time = 0.25
			ear_flick_side = rng.randi_range(-1, 1) # 0 = both ears
	ear_flick_time = maxf(0.0, ear_flick_time - delta)
	var flick := sin((1.0 - ear_flick_time / 0.25) * PI) * deg_to_rad(25.0) if ear_flick_time > 0.0 else 0.0
	var celebrate := victory_weight * deg_to_rad(18.0) * absf(sin(time * TAU * VICTORY_HOP_HZ))
	var droop := -defeat_weight * deg_to_rad(15.0)
	for i in 2:
		var side := -1 if i == 0 else 1
		var up := celebrate + droop
		if ear_flick_side == 0 or ear_flick_side == side:
			up += flick
		# Ears point along ±X: rotating about Z lifts the tip, about Y sweeps it back.
		ear_pivots[i].rotation = Vector3(0.0, -side * ear_back, side * up)


func _update_tail(walk: float) -> void:
	if tail_pivot == null:
		return
	var hz := 0.5 + 1.2 * minf(walk, 1.0) + victory_weight * 2.0
	var amplitude := deg_to_rad(8.0 + 10.0 * minf(walk, 1.0))
	# The tail hangs down from its root: negative X rotation swings the tip backward and up.
	tail_pivot.rotation = Vector3(-tail_lift, 0.0, amplitude * sin(time * TAU * hz))


func _is_paused() -> bool:
	return controller != null and controller.paused
