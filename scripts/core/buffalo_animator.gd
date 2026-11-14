class_name BuffaloAnimator
extends Node3D
## Visual-only procedural motion for the unrigged buffalo model (animation stage A).
## Moves this node, a runtime HERO leg skeleton and legacy ear/tail pivots; the physics body is never touched,
## so gameplay, LAN and combat tests are unaffected. Motion is read from the body's actual
## displacement, which also works on a LAN client where velocity is not replicated.

const POSE_RATE := 12.0
const SNAP_RATE := 32.0
const MOTION_FILTER_RATE := 12.0
const TELEPORT_DISTANCE := 3.0
const BOB_HEIGHT := 0.05
const SWAY_ROLL_DEG := 2.5
const ROCK_PITCH_DEG := 1.5
const ACCEL_PITCH_DEG_PER_MS2 := 0.12
const ACCEL_PITCH_MAX_DEG := 6.0
## Most the body may tip nose-up (about the hips) before the front hooves visibly leave the ground.
const MAX_NOSE_UP_DEG := 3.0
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
# Measured from buffalo_hero.glb (forward = -Z). Per leg, front-left, front-right,
# rear-left, rear-right: (x, knee/hock height, z, shoulder/hip height).
const LEG_JOINTS: Array[Vector4] = [
	Vector4(-0.34, 0.42, -0.33, 0.95), Vector4(0.34, 0.42, -0.33, 0.95),
	Vector4(-0.23, 0.48, 1.17, 1.0), Vector4(0.23, 0.48, 1.17, 1.0),
]
# Plan-view skin radius per leg: fully attached inside x, free of the leg beyond y.
const LEG_RADII: Array[Vector2] = [Vector2(0.2, 0.3), Vector2(0.2, 0.3), Vector2(0.15, 0.22), Vector2(0.15, 0.22)]
const LEG_HOOF_FORWARD_SQUASH := 0.6
# Vertices below x follow the leg fully; above y they belong to the torso.
const LEG_ATTACH_Y := Vector2(0.58, 0.85)
const LEG_KNEE_BLEND := 0.07

var buffalo: Buffalo
var controller: MatchController
var speed := 0.0
var local_velocity := Vector3.ZERO
var leg_mesh: MeshInstance3D
## Visual-only leg rig built at runtime (null on the legacy model).
var leg_skeleton: Skeleton3D
## Per leg (FL, FR, RL, RR): planned hoof travel in model space; y is the lift.
var hoof_offsets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var forward_speed := 0.0
var forward_accel := 0.0
var turn_rate := 0.0
var gait_phase := 0.0
var time := 0.0
var pose_offset := Vector3.ZERO
var pose_pitch := 0.0
var pose_roll := 0.0
var pose_yaw := 0.0
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
var _target_yaw := 0.0
var _target_rate := POSE_RATE
var _target_ear_back := 0.0
var _target_tail_lift := 0.0
var _gait_weight := 1.0
var _shake_roll := 0.0
var _last_position := Vector3.ZERO
var _last_yaw := 0.0
var clash_gait_weight := 0.0
# Speed at which a full stride is taken: the walk speed, or the slower led walk out of the
# arena after a defeat (FLEE), so the loser takes full steps instead of shuffling.
var _gait_reference_speed := 8.75
var _action_visual_state := -1
var _action_visual_time := 0.0
# Which side the next horn swing's slash VFX sweeps from (+1/-1); flips on every swing.
# Presentation bookkeeping only: it does not change the pose.
var _hook_side := -1.0


func _ready() -> void:
	buffalo = get_parent() as Buffalo
	var node := get_parent()
	while node != null and not node is MatchController:
		node = node.get_parent()
	controller = node as MatchController
	rng.seed = get_instance_id()
	_build_pivots()
	_build_leg_shapes()
	reset_motion()


func _physics_process(delta: float) -> void:
	if _is_paused() or (controller != null and controller.hitstop_ticks > 0):
		return
	sample_motion(delta)


func _process(delta: float) -> void:
	if _is_paused() or (controller != null and controller.hitstop_ticks > 0):
		return
	update_pose(delta)


func reset_motion() -> void:
	if buffalo == null:
		return
	_last_position = buffalo.global_position
	_last_yaw = buffalo.global_rotation.y
	speed = 0.0
	local_velocity = Vector3.ZERO
	forward_speed = 0.0
	forward_accel = 0.0
	turn_rate = 0.0
	clash_gait_weight = 0.0
	_action_visual_state = -1
	_action_visual_time = 0.0


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
	local_velocity = local_velocity.lerp(buffalo.global_basis.inverse() * planar, filter)
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
	_update_action_clock(delta)
	_compute_targets()
	var k := 1.0 - exp(-_target_rate * delta)
	pose_offset = pose_offset.lerp(_target_offset, k)
	pose_pitch = lerpf(pose_pitch, _target_pitch, k)
	pose_roll = lerpf(pose_roll, _target_roll, k)
	pose_yaw = lerpf(pose_yaw, _target_yaw, k)
	var soft := 1.0 - exp(-POSE_RATE * delta)
	ear_back = lerpf(ear_back, _target_ear_back, soft)
	tail_lift = lerpf(tail_lift, _target_tail_lift, soft)
	var result := _result_for_self()
	victory_weight = lerpf(victory_weight, 1.0 if result > 0 else 0.0, soft * 0.5)
	defeat_weight = lerpf(defeat_weight, 1.0 if result < 0 else 0.0, soft * 0.5)

	var fleeing := buffalo.state == Buffalo.State.FLEE
	_gait_reference_speed = GameBalance.get_number("result_lead_speed") if fleeing else GameBalance.get_number("walk_speed", 8.75)
	var walk_speed := _gait_reference_speed
	# Distance-driven cadence: no cycling feet at rest or on a blocked body.
	clash_gait_weight = lerpf(clash_gait_weight, 1.0 if buffalo.state == Buffalo.State.CLASH else 0.0, soft)
	var base_stride := GameBalance.get_number("result_lead_stride_length") if fleeing else GameBalance.get_number("gait_stride_length", 3.65)
	var stride := lerpf(base_stride, GameBalance.get_number("clash_gait_stride_length", 0.8), clash_gait_weight)
	gait_phase = fposmod(gait_phase + delta * speed / stride, 1.0)
	_update_legs()
	var walk := clampf(speed / walk_speed, 0.0, 1.3) * _gait_weight
	var bob := BOB_HEIGHT * walk * (0.5 - 0.5 * cos(gait_phase * TAU * 2.0))
	var hop := victory_weight * VICTORY_HOP_HEIGHT * absf(sin(time * TAU * VICTORY_HOP_HZ))

	var accel_pitch := clampf(-forward_accel * ACCEL_PITCH_DEG_PER_MS2, -ACCEL_PITCH_MAX_DEG, ACCEL_PITCH_MAX_DEG)
	var turn_roll := clampf(turn_rate * TURN_ROLL_DEG_PER_RAD_S, -TURN_ROLL_MAX_DEG, TURN_ROLL_MAX_DEG) * (0.4 + 0.6 * minf(walk, 1.0))
	# The body pitches about the hips, so nose-up lifts the front hooves off the dirt:
	# cap it (stun recoil + braking stacked to ~16 deg and read as a floating buck).
	var pitch := minf(pose_pitch + deg_to_rad(
		accel_pitch
		+ walk * ROCK_PITCH_DEG * sin(gait_phase * TAU * 2.0 + 0.8)
		- defeat_weight * 8.0
	), deg_to_rad(MAX_NOSE_UP_DEG)) + deg_to_rad(victory_weight * 6.0 * sin(time * TAU * VICTORY_HOP_HZ * 2.0))
	pitch = -_soft_nose_down(-pitch)
	var roll := pose_roll + deg_to_rad(turn_roll + walk * SWAY_ROLL_DEG * sin(gait_phase * TAU)) + _shake_roll
	var rotation_basis := Basis.from_euler(Vector3(pitch, pose_yaw, roll))
	var breath := 1.0 + BREATH_SCALE * sin(time * TAU * BREATH_HZ) * (1.0 - minf(walk, 1.0))
	var shaped := rotation_basis * Basis.from_scale(Vector3(1.0, breath, 1.0))
	var origin := PITCH_PIVOT - shaped * PITCH_PIVOT + pose_offset + Vector3(0.0, bob + hop, 0.0)
	transform = Transform3D(shaped, origin)
	_ground_legs()
	_update_ears(delta, result)
	_update_tail(walk)


func _compute_targets() -> void:
	_target_offset = Vector3.ZERO
	_target_pitch = 0.0
	_target_roll = 0.0
	_target_yaw = 0.0
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
		Buffalo.State.HORN_STARTUP, Buffalo.State.HORN_ACTIVE, Buffalo.State.HORN_RECOVERY:
			_compute_horn_targets()
		Buffalo.State.DASH_ACTIVE, Buffalo.State.DASH_RECOVERY:
			_compute_dash_targets()
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
			# Display only: a clockwise turn (seen from above) lets the two muzzles slide past each other.
			_target_yaw = -deg_to_rad(GameBalance.get_number("clash_visual_yaw_deg", 10.0))
			_target_ear_back = deg_to_rad(45.0)
			# Small body bob, but hooves still step according to real displacement.
			_gait_weight = 0.15
			_shake_roll = deg_to_rad(1.5) * sin(time * 21.0)
		Buffalo.State.FLEE:
			_target_pitch = deg_to_rad(5.0)
			_target_tail_lift = deg_to_rad(35.0)
			_target_ear_back = deg_to_rad(40.0)
			# Trembles while standing beaten; steadies once it is led away.
			_shake_roll = deg_to_rad(5.0) * sin(time * TAU * 3.0) * (1.0 - clampf(speed / _gait_reference_speed, 0.0, 1.0))


## LAN client only: called when a snapshot delivers this buffalo's `state_time`.
## The visual clock then counts the time since that snapshot, so an action's pose
## keeps moving smoothly until the next snapshot arrives.
func sync_action_clock() -> void:
	_action_visual_time = 0.0


# Visual-only clock on top of the last snapshot's `state_time`; it never advances
# gameplay states. Restarts when the state changes or a snapshot syncs it.
func _update_action_clock(delta: float) -> void:
	if _action_visual_state != buffalo.state:
		if buffalo.state == Buffalo.State.HORN_STARTUP:
			_hook_side = -_hook_side
		_action_visual_state = buffalo.state
		_action_visual_time = 0.0
	else:
		_action_visual_time += delta


func _action_progress(duration_key: String) -> float:
	var remote: bool = controller != null and controller.mode == &"LAN" and controller.network != null and not controller.network.is_host
	var duration := buffalo.state_duration if buffalo.state_duration > 0.0 else GameBalance.get_number(duration_key)
	var elapsed := _action_visual_time + buffalo.state_time if remote else buffalo.state_time
	return clampf(elapsed / duration, 0.0, 1.0) if duration > 0.0 else 1.0


func _compute_dash_targets() -> void:
	var recovering := buffalo.state == Buffalo.State.DASH_RECOVERY
	var progress := _action_progress("dash_recovery_s" if recovering else "dash_active_s")
	var reach := GameBalance.get_number("dash_visual_reach", 0.16)
	var dip := GameBalance.get_number("dash_visual_dip_deg", 12.0)
	_target_rate = SNAP_RATE * 1.3
	if not recovering:
		# Immediate compression and drive, then unload before recovery. This
		# never delays the gameplay dash or adds displacement to its physics body.
		var drive := smoothstep(0.0, 0.3, progress)
		var unload := smoothstep(0.65, 1.0, progress)
		_target_offset = Vector3(0.0, lerpf(-0.055, -0.02, drive), -reach * drive)
		_target_pitch = deg_to_rad(-dip * (1.0 - 0.5 * unload))
		_target_ear_back = deg_to_rad(50.0)
		_target_tail_lift = deg_to_rad(55.0)
		_gait_weight = lerpf(0.6, 1.3, drive)
	else:
		var brake := smoothstep(0.0, 0.35, progress)
		var settle := smoothstep(0.35, 1.0, progress)
		var recoil := GameBalance.get_number("dash_visual_brake_pitch_deg", 5.0)
		_target_offset = Vector3(0.0, -0.02 * (1.0 - brake), lerpf(-reach, 0.04, brake) * (1.0 - settle))
		_target_pitch = deg_to_rad(lerpf(-dip * 0.5, recoil, brake) * (1.0 - settle))
		_target_ear_back = deg_to_rad(50.0 * (1.0 - progress))
		_target_tail_lift = deg_to_rad(55.0 * (1.0 - progress))
		_gait_weight = lerpf(0.5, 1.0, settle)


func _compute_horn_targets() -> void:
	var duration_key := "horn_startup_s"
	if buffalo.state == Buffalo.State.HORN_ACTIVE:
		duration_key = "horn_active_s"
	elif buffalo.state == Buffalo.State.HORN_RECOVERY:
		duration_key = "horn_recovery_s"
	var progress := _action_progress(duration_key)
	var windup := GameBalance.get_number("horn_visual_windup", 0.12)
	var reach := GameBalance.get_number("horn_visual_reach", 0.24)
	var dip := GameBalance.get_number("horn_startup_head_pitch_deg")
	var toss := GameBalance.get_number("horn_visual_toss_deg", 6.0)
	_target_rate = SNAP_RATE * 1.3
	match buffalo.state:
		Buffalo.State.HORN_STARTUP:
			var load_weight := smoothstep(0.0, 1.0, progress)
			_target_offset = Vector3(0.0, -0.03 * load_weight, windup * load_weight)
			_target_pitch = deg_to_rad(-dip * load_weight)
			_target_ear_back = deg_to_rad(30.0 * load_weight)
			_gait_weight = lerpf(1.0, 0.3, load_weight)
		Buffalo.State.HORN_ACTIVE:
			var drive := smoothstep(0.0, 0.35, progress)
			var lift := smoothstep(0.2, 0.9, progress)
			_target_offset = Vector3(0.0, lerpf(-0.03, 0.0, drive), lerpf(windup, -reach, drive))
			_target_pitch = deg_to_rad(lerpf(-dip, toss, lift))
			_target_ear_back = deg_to_rad(30.0)
			_gait_weight = lerpf(0.3, 0.5, drive)
		Buffalo.State.HORN_RECOVERY:
			var settle := smoothstep(0.0, 1.0, progress)
			_target_offset.z = -reach * (1.0 - settle)
			_target_pitch = deg_to_rad(toss * (1.0 - settle))
			_target_ear_back = deg_to_rad(30.0 * (1.0 - settle))
			_gait_weight = lerpf(0.5, 1.0, settle)


# +1 when this buffalo is winning the CLASH tug-of-war, -1 when losing.
func _clash_advantage() -> float:
	if controller == null or controller.active_clash.is_empty():
		return 0.0
	var balance := float(controller.active_clash.get("lock_balance", 0.0)) / GameBalance.get_number("lock_balance_max", 100.0)
	return clampf(balance if controller.active_clash.get("a") == buffalo else -balance, -1.0, 1.0)


# 1 = this buffalo won the match, -1 = lost, 0 = still playing or no winner.
func _result_for_self() -> int:
	if controller == null or not controller.finished or controller.winner_slot == 0:
		return 0
	if controller.outro.is_revealing_lot():
		return 0
	if buffalo.state == Buffalo.State.FLEE:
		return 0
	return 1 if controller.winner_slot == buffalo.slot else -1


# The HERO asset is a joined mesh without a rig. Build a visual-only leg skeleton once:
# each leg gets an upper bone (shoulder/hip, inside the body) and a lower bone (knee or
# hock), and vertices are skinned to them with smooth masks. Legs then swing and fold by
# rotation, so they keep their length instead of shearing. Surfaces, materials and UVs
# are preserved; the imported resource stays untouched.
func _build_leg_shapes() -> void:
	leg_mesh = find_child("HeroBody", true, false) as MeshInstance3D
	if leg_mesh == null or leg_mesh.mesh == null or leg_mesh.get_parent() == null:
		return
	leg_skeleton = Skeleton3D.new()
	leg_skeleton.name = "LegSkeleton"
	leg_mesh.get_parent().add_child(leg_skeleton)
	leg_skeleton.transform = leg_mesh.transform
	leg_skeleton.add_bone("Root")
	var skin := Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	for leg in 4:
		var joint: Vector4 = LEG_JOINTS[leg]
		var upper := leg_skeleton.add_bone("Leg%d_Upper" % leg)
		leg_skeleton.set_bone_parent(upper, 0)
		leg_skeleton.set_bone_rest(upper, Transform3D(Basis(), Vector3(joint.x, joint.w, joint.z)))
		var lower := leg_skeleton.add_bone("Leg%d_Lower" % leg)
		leg_skeleton.set_bone_parent(lower, upper)
		leg_skeleton.set_bone_rest(lower, Transform3D(Basis(), Vector3(0.0, joint.y - joint.w, 0.0)))
		skin.add_bind(upper, Transform3D(Basis(), -Vector3(joint.x, joint.w, joint.z)))
		skin.add_bind(lower, Transform3D(Basis(), -Vector3(joint.x, joint.y, joint.z)))
	leg_skeleton.reset_bone_poses()
	var source := leg_mesh.mesh
	var animated := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for i in vertices.size():
			var vertex := vertices[i]
			var leg := _leg_for_vertex(vertex)
			bones[i * 4] = 0
			weights[i * 4] = 1.0
			if leg < 0:
				continue
			var joint: Vector4 = LEG_JOINTS[leg]
			var radius: Vector2 = LEG_RADII[leg]
			var offset := Vector2(vertex.x - joint.x, vertex.z - joint.z)
			if offset.y < 0.0:
				offset.y *= LEG_HOOF_FORWARD_SQUASH # hooves reach forward of the leg column
			var member := 1.0 - smoothstep(radius.x, radius.y, offset.length())
			var attach := 1.0 - smoothstep(LEG_ATTACH_Y.x, LEG_ATTACH_Y.y, vertex.y)
			var leg_weight := member * attach
			var below_knee := 1.0 - smoothstep(joint.y - LEG_KNEE_BLEND, joint.y + LEG_KNEE_BLEND, vertex.y)
			weights[i * 4] = 1.0 - leg_weight
			bones[i * 4 + 1] = 1 + leg * 2
			weights[i * 4 + 1] = leg_weight * (1.0 - below_knee)
			bones[i * 4 + 2] = 2 + leg * 2
			weights[i * 4 + 2] = leg_weight * below_knee
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		animated.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		animated.surface_set_material(surface, source.surface_get_material(surface))
	leg_mesh.mesh = animated
	leg_mesh.skin = skin
	leg_mesh.skeleton = leg_mesh.get_path_to(leg_skeleton)


# The leg whose column is closest to `vertex` in plan view, or -1 above the legs.
func _leg_for_vertex(vertex: Vector3) -> int:
	if vertex.y >= LEG_ATTACH_Y.y:
		return -1
	var best := -1
	var best_distance := INF
	for leg in 4:
		var joint: Vector4 = LEG_JOINTS[leg]
		var distance := Vector2(vertex.x - joint.x, vertex.z - joint.z).length()
		if distance < best_distance:
			best_distance = distance
			best = leg
	return best


func _update_legs() -> void:
	if leg_skeleton == null:
		return
	var amount := clampf(speed / _gait_reference_speed, 0.0, 1.0) * minf(_gait_weight, 1.0)
	# Clash moves much slower than a walk: use its own reference speed and
	# low, short steps instead of scaling the regular trot down to invisibility.
	var clash_amount := clampf(speed / GameBalance.get_number("lock_slide_speed", 1.7), 0.0, 1.0)
	var reach := lerpf(GameBalance.get_number("gait_step_reach", 0.28) * amount, GameBalance.get_number("clash_gait_step_reach", 0.1) * clash_amount, clash_gait_weight)
	var lift := lerpf(GameBalance.get_number("gait_hoof_lift", 0.14) * amount, GameBalance.get_number("clash_gait_hoof_lift", 0.05) * clash_amount, clash_gait_weight)
	var direction := local_velocity.normalized() if local_velocity.length_squared() > 0.001 else Vector3.ZERO
	# Sideways steps are narrower than forward strides: legs barely abduct.
	direction.x *= GameBalance.get_number("gait_lateral_scale", 0.55)
	for leg in 4:
		# Diagonal pairs alternate in a heavy trot. During stance the hoof travels
		# backwards relative to the body; the return stroke lifts it off the dirt.
		var phase := fposmod(gait_phase + (0.5 if leg == 1 or leg == 2 else 0.0), 1.0)
		var swing := phase >= 0.6
		var progress := (phase - 0.6) / 0.4 if swing else phase / 0.6
		var travel := lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, progress)) if swing else lerpf(1.0, -1.0, progress)
		hoof_offsets[leg] = Vector3(direction.x * travel * reach, sin(progress * PI) * lift if swing else 0.0, direction.z * travel * reach)
		_pose_leg(leg, hoof_offsets[leg])


# Turns a hoof offset (plan-view travel + lift, model space) into bone rotations: the
# upper bone swings the whole leg about the shoulder/hip so the hoof lands at the
# planned spot, the lower bone folds the knee (front: hoof curls back) or hock (rear:
# hoof tucks forward) to lift it without stretching the leg.
func _pose_leg(leg: int, offset: Vector3) -> void:
	var joint: Vector4 = LEG_JOINTS[leg]
	var planar := Vector3(offset.x, 0.0, offset.z)
	var swing_rotation := Quaternion.IDENTITY
	if planar.length_squared() > 0.000001:
		var axis := Vector3.DOWN.cross(planar.normalized()).normalized()
		swing_rotation = Quaternion(axis, atan2(planar.length(), joint.w))
	var lower_length := joint.y
	# Part of the lift comes from the swing arc and the body bob, so the joint folds
	# less than the full lift would need; a fully folded hoof flips up and reads wrong.
	var fold := acos(clampf(1.0 - offset.y / lower_length, -1.0, 1.0)) * GameBalance.get_number("gait_knee_fold_scale", 0.65)
	var fold_sign := -1.0 if leg < 2 else 1.0
	leg_skeleton.set_bone_pose_rotation(1 + leg * 2, swing_rotation)
	leg_skeleton.set_bone_pose_rotation(2 + leg * 2, Quaternion(Vector3.RIGHT, fold_sign * fold))


# Nose-down pitch eases into `max_nose_down_deg` past `nose_down_soft_deg`. The body pitches
# about the rear hooves, so every degree lowers the shoulders: past ~12 deg the grounded
# front legs fold so far the buffalo reads as kneeling instead of charging.
func _soft_nose_down(down: float) -> float:
	var soft := deg_to_rad(GameBalance.get_number("nose_down_soft_deg", 8.0))
	var cap := deg_to_rad(GameBalance.get_number("max_nose_down_deg", 12.0))
	if down <= soft or cap <= soft:
		return minf(down, cap)
	return soft + (cap - soft) * tanh((down - soft) / (cap - soft))


# The body pitches about the rear hooves, so a nose-down pose (horn load, dash dip, clash
# shove) would push straight front legs about half a metre into the dirt. Once the body
# is placed, any hoof below the ground is lifted back onto it by bending that leg with a
# two-bone solve: the knee juts forward on a front leg, the hock backward on a rear leg.
# Front hooves also reach forward with the dip (`leg_ground_brace`), bracing for the shove.
# Legs that stay above the ground keep their gait pose untouched.
func _ground_legs() -> void:
	if leg_skeleton == null or buffalo == null or not is_inside_tree():
		return
	var to_buffalo := buffalo.global_transform.affine_inverse() * leg_skeleton.global_transform
	var to_skeleton := to_buffalo.affine_inverse()
	var blend := maxf(GameBalance.get_number("leg_ground_blend_m", 0.03), 0.001)
	for leg in 4:
		var joint: Vector4 = LEG_JOINTS[leg]
		var upper_length := joint.w - joint.y
		var lower_length := joint.y
		var shoulder := Vector3(joint.x, joint.w, joint.z)
		var upper_pose := leg_skeleton.get_bone_pose_rotation(1 + leg * 2)
		var lower_pose := leg_skeleton.get_bone_pose_rotation(2 + leg * 2)
		var hoof := shoulder + upper_pose * Vector3(0.0, -upper_length, 0.0) + upper_pose * lower_pose * Vector3(0.0, -lower_length, 0.0)
		var planted := to_buffalo * hoof
		var sink := -planted.y
		if sink <= 0.0:
			continue
		var ground := Vector3(planted.x, 0.0, planted.z)
		if leg < 2:
			# A charging buffalo braces its front legs ahead of the shoulders rather than
			# kneeling under them: plant the hoof forward in proportion to the dip.
			var forward := to_buffalo.basis * Vector3.FORWARD
			forward.y = 0.0
			ground += forward.normalized() * sink * GameBalance.get_number("leg_ground_brace", 0.9)
		var target := to_skeleton * ground
		var reach := target - shoulder
		var distance := clampf(reach.length(), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
		var along := reach.normalized()
		var pole := Vector3(0.0, 0.0, -1.0 if leg < 2 else 1.0)
		pole = (pole - along * pole.dot(along)).normalized()
		var cos_shoulder := clampf((upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * upper_length * distance), -1.0, 1.0)
		var knee_dir := along * cos_shoulder + pole * sqrt(1.0 - cos_shoulder * cos_shoulder)
		var knee := shoulder + knee_dir * upper_length
		var solved_upper := Quaternion(Vector3.DOWN, knee_dir)
		var solved_lower := Quaternion(Vector3.DOWN, solved_upper.inverse() * (shoulder + along * distance - knee).normalized())
		# Ease in over the first few centimetres so a hoof grazing the ground never pops.
		var weight := clampf(sink / blend, 0.0, 1.0)
		leg_skeleton.set_bone_pose_rotation(1 + leg * 2, upper_pose.slerp(solved_upper, weight))
		leg_skeleton.set_bone_pose_rotation(2 + leg * 2, lower_pose.slerp(solved_lower, weight))


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


## Read-only, for VFX: a point given in the visual's rest space (e.g. the horn tips), in the
## buffalo body's space after this frame's pose.
func head_point(rest: Vector3) -> Vector3:
	return buffalo.to_local(to_global(rest)) if buffalo != null and is_inside_tree() else transform * rest


## Read-only, for VFX: where the hoof of `leg` is this frame, in the buffalo body's space.
func hoof_position(leg: int) -> Vector3:
	var joint: Vector4 = LEG_JOINTS[leg]
	if leg_skeleton == null or buffalo == null or not is_inside_tree():
		return transform * Vector3(joint.x, 0.0, joint.z)
	var lower := leg_skeleton.get_bone_global_pose(2 + leg * 2)
	return buffalo.to_local(leg_skeleton.to_global(lower * Vector3(0.0, -joint.y, 0.0)))
