extends SceneTree

const TICK := 1.0 / 60.0

var failures := 0
var arena: MatchController


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	arena = load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	var buffalo := arena.player
	var animator := buffalo.visual as BuffaloAnimator
	check(animator != null, "Visual node runs BuffaloAnimator")
	if animator == null:
		quit(1)
		return
	_test_pivots(buffalo, animator)
	_test_rest(buffalo, animator)
	_test_body_untouched(buffalo, animator)
	_test_state_poses(buffalo, animator)
	_test_horn_sequence(buffalo, animator)
	_test_dash_sequence(buffalo, animator)
	_test_walk(buffalo, animator)
	_test_legs(buffalo, animator)
	_test_hooves_stay_above_ground(buffalo, animator)
	_test_clash_steps(buffalo, animator)
	_test_led_out_steps(buffalo, animator)
	_test_turn_and_teleport(buffalo, animator)
	_test_result(animator, arena.opponent.visual as BuffaloAnimator)
	_test_pause(buffalo, animator)
	arena.free()
	print("ANIMATION TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _reset(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	buffalo.reset_combat()
	buffalo.position = Vector3.ZERO
	buffalo.rotation = Vector3.ZERO
	animator.reset_motion()


func _step(animator: BuffaloAnimator, ticks: int) -> void:
	for i in ticks:
		animator.sample_motion(TICK)
		animator.update_pose(TICK)


func _test_pivots(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	if buffalo.find_child("HeroBody", true, false) != null:
		check(animator.ear_pivots.is_empty() and animator.tail_pivot == null, "joined HERO mesh does not create invalid legacy pivots")
		check(buffalo.get_node("Visual/Model").find_children("*", "MeshInstance3D", true, false).size() == 2, "HERO body and faction cloth remain")
		return
	check(animator.ear_pivots.size() == 2 and animator.tail_pivot != null, "ear and tail pivots are created")
	for label in ["Ear_L", "EarInner_L", "Ear_R", "EarInner_R"]:
		var mesh := buffalo.find_child(label, true, false)
		check(mesh != null and mesh.get_parent().name.begins_with("EarPivot_"), "%s hangs from an ear pivot" % label)
	for label in ["Tail", "TailTuft"]:
		var mesh := buffalo.find_child(label, true, false)
		check(mesh != null and mesh.get_parent() == animator.tail_pivot, "%s hangs from the tail pivot" % label)
	var meshes := buffalo.get_node("Visual/Model").find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 25, "all 25 model meshes remain (found %d)" % meshes.size())


func _test_rest(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	_reset(buffalo, animator)
	_step(animator, 180)
	var euler := animator.basis.get_euler()
	check(animator.position.length() < 0.01, "standing still: Visual offset returns to ~0")
	check(absf(euler.x) < deg_to_rad(0.5) and absf(euler.z) < deg_to_rad(0.5), "standing still: Visual is level")
	check(absf(animator.basis.get_scale().y - 1.0) <= BuffaloAnimator.BREATH_SCALE + 0.001, "idle breathing stays within its small scale range")
	var ear := buffalo.find_child("Ear_L", true, false) as Node3D
	if ear != null:
		animator.ear_pivots[0].rotation = Vector3.ZERO
		check(ear.global_position.distance_to(buffalo.global_position) < 0.01, "reparented ear keeps its rest position")


func _test_body_untouched(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	_reset(buffalo, animator)
	var before := buffalo.global_transform
	for state in Buffalo.State.values():
		buffalo.state = state
		buffalo.state_time = 0.05
		buffalo.state_duration = 0.2
		_step(animator, 20)
	check(buffalo.global_transform.is_equal_approx(before), "animator never moves or rotates the physics body")
	check(buffalo.get_node("Body").position.is_equal_approx(Vector3(0.0, 1.0, 0.275)) and buffalo.get_node("Head").position.is_equal_approx(Vector3(0.0, 1.0, -0.8)), "collision shapes are not animated")
	buffalo.state = Buffalo.State.NORMAL


func _pose_for(buffalo: Buffalo, animator: BuffaloAnimator, state: Buffalo.State, progress := 0.5) -> void:
	_reset(buffalo, animator)
	_step(animator, 60)
	buffalo.state = state
	buffalo.state_duration = 0.2
	buffalo.state_time = 0.2 * progress
	_step(animator, 30)


func _test_state_poses(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	_pose_for(buffalo, animator, Buffalo.State.HORN_STARTUP, 1.0)
	check(animator.pose_pitch < deg_to_rad(-5.0) and animator.pose_offset.z > 0.05, "HORN startup: head dips and body winds back")
	_pose_for(buffalo, animator, Buffalo.State.HORN_ACTIVE, 0.4)
	check(animator.pose_offset.z < -0.2, "HORN active: body lunges forward")
	var early := animator.pose_pitch
	_pose_for(buffalo, animator, Buffalo.State.HORN_ACTIVE, 1.0)
	check(animator.pose_pitch > early, "HORN active: horns toss upward through the window")
	_pose_for(buffalo, animator, Buffalo.State.GUARD)
	check(animator.pose_offset.y < 0.0 and animator.pose_offset.z > 0.0 and animator.ear_back > deg_to_rad(20.0), "GUARD: low, braced back, ears pinned")
	_pose_for(buffalo, animator, Buffalo.State.DASH_ACTIVE)
	check(animator.pose_pitch < deg_to_rad(-8.0) and animator.tail_lift > deg_to_rad(30.0), "DASH: nose down, tail up")
	_pose_for(buffalo, animator, Buffalo.State.STUNNED, 0.1)
	check(animator.pose_pitch > deg_to_rad(5.0), "STUNNED: recoils nose-up")
	_pose_for(buffalo, animator, Buffalo.State.STUNNED, 1.0)
	check(absf(animator.pose_pitch) < deg_to_rad(1.0), "STUNNED: recoil fades out by the end of the stun")
	_pose_for(buffalo, animator, Buffalo.State.CLASH)
	check(animator.pose_pitch < deg_to_rad(-8.0), "CLASH: heads locked low")
	_pose_for(buffalo, animator, Buffalo.State.NORMAL)
	check(animator.pose_offset.length() < 0.01 and absf(animator.pose_pitch) < 0.01, "NORMAL: pose returns to neutral")

	# CLASH lean follows the tug-of-war balance.
	_reset(buffalo, animator)
	arena.active_clash = {"a": arena.player, "b": arena.opponent, "time": 0.0, "lock_balance": 80.0}
	buffalo.state = Buffalo.State.CLASH
	_step(animator, 60)
	check(animator.pose_offset.z < -0.1, "CLASH: the winning side leans in")
	arena.active_clash = {"a": arena.opponent, "b": arena.player, "time": 0.0, "lock_balance": 80.0}
	_step(animator, 60)
	check(animator.pose_offset.z > 0.1, "CLASH: the losing side is pushed back")
	arena.active_clash.clear()
	buffalo.state = Buffalo.State.NORMAL


func _test_horn_sequence(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	var endpoints: Array[Vector2] = []
	for fps in [30, 60, 120]:
		_reset(buffalo, animator)
		_step(animator, 120)
		var body_before := buffalo.global_transform
		var dt: float = 1.0 / fps
		buffalo.start_horn()
		var stamina_after := buffalo.stamina
		var deepest := 0.0
		var farthest := 0.0
		var previous := animator.position
		var largest_step := 0.0
		var sequence_s := GameBalance.get_number("horn_startup_s") + GameBalance.get_number("horn_active_s") + GameBalance.get_number("horn_whiff_recovery_s") + 0.3
		for i in int(sequence_s * fps):
			animator.update_pose(dt)
			deepest = minf(deepest, animator.pose_pitch)
			farthest = minf(farthest, animator.pose_offset.z)
			largest_step = maxf(largest_step, animator.position.distance_to(previous))
			previous = animator.position
			buffalo.advance_state(dt)
		check(deepest < deg_to_rad(-3.0) and farthest < -0.15, "horn sequence loads then drives at %d FPS" % fps)
		check(largest_step < 0.4, "horn sequence has bounded frame displacement at %d FPS" % fps)
		check(animator.pose_offset.length() < 0.01 and absf(animator.pose_pitch) < 0.01, "horn recovery settles at %d FPS" % fps)
		check(buffalo.global_transform.is_equal_approx(body_before) and buffalo.velocity == Vector3.ZERO, "horn visual never adds root motion")
		check(is_equal_approx(buffalo.stamina, stamina_after), "horn visual never changes stamina")
		endpoints.append(Vector2(deepest, farthest))
	for endpoint in endpoints:
		check(endpoint.distance_to(endpoints[1]) < 0.06, "horn motion is comparable across frame rates")
	for interrupted in [Buffalo.State.STUNNED, Buffalo.State.CLASH, Buffalo.State.NORMAL]:
		_pose_for(buffalo, animator, Buffalo.State.HORN_ACTIVE, 0.7)
		buffalo.state = interrupted
		buffalo.state_time = 0.0
		buffalo.state_duration = 0.2
		_step(animator, 30)
		check(animator.transform.is_finite(), "interrupted horn pose stays finite")
	# LAN snapshots only carry action names: the visual clock must still progress.
	var old_mode := arena.mode
	var old_host: bool = arena.network.is_host
	arena.mode = &"LAN"
	arena.network.is_host = false
	_reset(buffalo, animator)
	buffalo.state = Buffalo.State.HORN_ACTIVE
	buffalo.state_duration = 0.0
	_step(animator, 12)
	check(animator.pose_offset.z < -0.15 and animator.pose_pitch > 0.0, "LAN horn progresses without replicated state timing")
	buffalo.state = Buffalo.State.HORN_RECOVERY
	_step(animator, 30)
	check(animator.pose_offset.length() < 0.01, "LAN horn recovery settles using visual time")
	arena.mode = old_mode
	arena.network.is_host = old_host
	_reset(buffalo, animator)
	buffalo.state = Buffalo.State.HORN_ACTIVE
	buffalo.state_duration = 0.0
	_step(animator, 1)
	check(animator.transform.is_finite(), "zero-duration horn pose stays finite")
	_reset(buffalo, animator)


func _test_dash_sequence(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	var endpoints: Array[Vector2] = []
	for fps in [30, 60, 120]:
		_reset(buffalo, animator)
		_step(animator, 120)
		var dt: float = 1.0 / fps
		check(buffalo.start_dash(), "dash starts immediately")
		check(is_equal_approx(buffalo.velocity.length(), GameBalance.get_number("dash_speed")), "dash visual does not delay gameplay speed")
		var stamina := buffalo.stamina
		var cooldown := buffalo.dash_cooldown
		var deepest := 0.0
		var forward := 0.0
		var brake := 0.0
		for i in int(0.8 * fps):
			var before := buffalo.global_transform
			var velocity := buffalo.velocity
			var state := buffalo.state
			var elapsed := buffalo.state_time
			animator.update_pose(dt)
			if i == 1:
				check(buffalo.global_transform.is_equal_approx(before) and buffalo.velocity == velocity and buffalo.state == state and buffalo.state_time == elapsed, "dash animator never modifies gameplay")
			deepest = minf(deepest, animator.pose_pitch)
			forward = minf(forward, animator.pose_offset.z)
			if buffalo.state == Buffalo.State.DASH_RECOVERY:
				brake = maxf(brake, animator.pose_pitch)
			buffalo.advance_state(dt)
		check(deepest < deg_to_rad(-7.0) and forward < -0.1, "dash compresses and drives at %d FPS" % fps)
		check(brake > deg_to_rad(1.0), "dash recovery shows braking at %d FPS" % fps)
		check(animator.pose_offset.length() < 0.01 and absf(animator.pose_pitch) < 0.01, "dash returns to neutral at %d FPS" % fps)
		check(is_equal_approx(buffalo.stamina, stamina) and is_equal_approx(buffalo.dash_cooldown, cooldown), "dash visual leaves cost and cooldown untouched")
		endpoints.append(Vector2(deepest, forward))
	for endpoint in endpoints:
		check(endpoint.distance_to(endpoints[1]) < 0.04, "dash motion is comparable across frame rates")
	for interrupted in [Buffalo.State.STUNNED, Buffalo.State.CLASH, Buffalo.State.NORMAL]:
		_pose_for(buffalo, animator, Buffalo.State.DASH_ACTIVE)
		buffalo.state = interrupted
		buffalo.state_time = 0.0
		_step(animator, 60)
		check(animator.transform.is_finite(), "interrupted dash stays finite")
		buffalo.state = Buffalo.State.NORMAL
		_step(animator, 120)
		check(animator.pose_offset.length() < 0.01, "interrupted dash leaves no residual offset")
	var old_mode := arena.mode
	var old_host: bool = arena.network.is_host
	arena.mode = &"LAN"
	arena.network.is_host = false
	_reset(buffalo, animator)
	buffalo.state = Buffalo.State.DASH_ACTIVE
	buffalo.state_duration = 0.0
	_step(animator, 10)
	check(animator.pose_offset.z < -0.1, "LAN dash progresses without replicated state timing")
	buffalo.state = Buffalo.State.DASH_RECOVERY
	_step(animator, 45)
	check(animator.pose_offset.length() < 0.01 and absf(animator.pose_pitch) < 0.01, "LAN dash recovery settles")
	arena.mode = old_mode
	arena.network.is_host = old_host
	_reset(buffalo, animator)
	buffalo.state = Buffalo.State.DASH_RECOVERY
	buffalo.state_duration = 0.0
	_step(animator, 1)
	check(animator.transform.is_finite(), "zero-duration dash recovery stays finite")
	_reset(buffalo, animator)


func _test_walk(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	_reset(buffalo, animator)
	_step(animator, 60)
	var walk_speed := GameBalance.get_number("walk_speed")
	var heading := -buffalo.global_basis.z
	var lowest := INF
	var highest := -INF
	var leaned_forward := false
	for i in 120:
		buffalo.position += heading * walk_speed * TICK
		_step(animator, 1)
		if i < 10 and animator.basis.get_euler().x < 0.0:
			leaned_forward = true
		if i >= 60:
			lowest = minf(lowest, animator.position.y)
			highest = maxf(highest, animator.position.y)
	check(absf(animator.speed - walk_speed) < walk_speed * 0.05, "measured speed follows the body's displacement")
	check(leaned_forward, "accelerating leans the body forward")
	check(highest - lowest > BuffaloAnimator.BOB_HEIGHT * 0.5, "walking bobs the body")
	for i in 120:
		_step(animator, 1)
	check(animator.speed < 0.05 and animator.position.length() < 0.02, "gait settles when the body stops")


func _test_legs(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	_reset(buffalo, animator)
	_step(animator, 120)
	if animator.leg_mesh == null:
		return # Legacy model has separate meshes rather than the joined HERO body.
	check(animator.leg_skeleton != null and animator.leg_skeleton.get_bone_count() == 9, "HERO gets a root plus upper/lower bones for each leg")
	check(animator.leg_mesh.skin != null and animator.leg_mesh.get_node_or_null(animator.leg_mesh.skeleton) == animator.leg_skeleton, "HERO body is skinned to the leg rig")
	var source := load("res://assets/characters/buffalo_hero/buffalo_hero.glb") as PackedScene
	var original := source.instantiate()
	var original_body := original.find_child("HeroBody", true, false) as MeshInstance3D
	check(original_body.skin == null and original_body.mesh.get_blend_shape_count() == 0, "procedural gait leaves imported mesh unchanged")
	original.free()
	var moved := false
	var lifted := false
	var folded := false
	for i in 90:
		buffalo.position.z -= GameBalance.get_number("walk_speed") * TICK
		_step(animator, 1)
		var left := animator.hoof_offsets[0]
		if left.y > 0.05:
			folded = folded or animator.leg_skeleton.get_bone_pose_rotation(2).get_angle() > 0.05
		moved = moved or absf(left.z) > 0.05
		lifted = lifted or left.y > 0.05
		if i == 60:
			check(left.is_equal_approx(animator.hoof_offsets[3]), "diagonal hooves share their stride")

	check(moved and lifted, "moving buffalo strides and lifts its hooves")
	check(folded, "a lifted hoof folds the knee instead of stretching the leg")
	for direction in [Vector3.BACK, Vector3.RIGHT]:
		_reset(buffalo, animator)
		for i in 90:
			buffalo.position += direction * 4.0 * TICK
			_step(animator, 1)
		check(animator.local_velocity.normalized().dot(direction) > 0.99, "gait follows backward/lateral displacement")
	_step(animator, 180)
	check(_legs_at_rest(animator), "all legs return to rest after stopping")
	var phase := animator.gait_phase
	_step(animator, 60)
	check(absf(animator.gait_phase - phase) < 0.001, "stride phase stops advancing at rest")


# Horn load, dash dip and clash shove pitch the body nose-down about the rear hooves;
# the front legs must bend onto the dirt instead of sinking into it (owner report 2026-11-15).
func _test_hooves_stay_above_ground(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	if animator.leg_mesh == null:
		return
	for action in ["horn", "dash", "clash"]:
		_reset(buffalo, animator)
		_step(animator, 60)
		if action == "horn":
			buffalo.start_horn()
		elif action == "dash":
			buffalo.start_dash()
		else:
			buffalo.state = Buffalo.State.CLASH
		var lowest := INF
		var deepest_pitch := 0.0
		for i in 90:
			animator.update_pose(TICK)
			if action != "clash":
				buffalo.advance_state(TICK)
			deepest_pitch = minf(deepest_pitch, animator.basis.get_euler().x)
			for leg in 4:
				lowest = minf(lowest, animator.hoof_position(leg).y)
		check(deepest_pitch < deg_to_rad(-6.0), "%s still dips the head clearly" % action)
		check(lowest > -0.02, "%s keeps every hoof on or above the ground (lowest %.3f m)" % [action, lowest])
		check(deepest_pitch >= deg_to_rad(-GameBalance.get_number("max_nose_down_deg")) - 0.001, "%s nose-down stays within the kneel-free limit" % action)


func _test_clash_steps(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	if animator.leg_mesh == null:
		return
	for direction in [Vector3.FORWARD, Vector3.BACK]:
		_reset(buffalo, animator)
		buffalo.state = Buffalo.State.CLASH
		_step(animator, 120)
		var lifted := 0.0
		var reach := 0.0
		var previous_phase := animator.gait_phase
		for i in 120:
			buffalo.position += direction * GameBalance.get_number("lock_slide_speed") * TICK
			var before := buffalo.global_transform
			_step(animator, 1)
			if i == 60:
				check(buffalo.global_transform.is_equal_approx(before), "clash steps never move the physics body")
			lifted = maxf(lifted, animator.hoof_offsets[0].y)
			reach = maxf(reach, absf(animator.hoof_offsets[0].z))
		check(lifted > 0.025 and lifted <= GameBalance.get_number("clash_gait_hoof_lift") + 0.001, "clash hooves lift in low steps")
		check(reach > 0.05 and reach <= GameBalance.get_number("clash_gait_step_reach") + 0.001, "clash steps stay short")
		check(animator.local_velocity.normalized().dot(direction) > 0.99, "clash gait follows push or retreat displacement")
		check(absf(animator.gait_phase - previous_phase) > 0.01, "moving clash advances stride phase")
		_step(animator, 180)
		check(_hooves_planted(animator), "stationary clash plants every hoof on the ground, even while bracing nose-down")
		var phase := animator.gait_phase
		_step(animator, 60)
		check(absf(animator.gait_phase - phase) < 0.001, "stationary clash never cycles hooves in place")
	buffalo.state = Buffalo.State.NORMAL
	_step(animator, 60)
	check(animator.clash_gait_weight < 0.001, "leaving clash restores regular gait")
	_reset(buffalo, animator)


# Regression: the loser led out of the arena (FLEE, slow walk) used to shuffle with ~half-size
# steps, invisible from the result camera; it must take full strides at the led-walk pace.
func _test_led_out_steps(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	if animator.leg_mesh == null:
		return
	_reset(buffalo, animator)
	buffalo.state = Buffalo.State.FLEE
	var reach := 0.0
	var lifted := 0.0
	for i in 180:
		buffalo.position += Vector3.FORWARD * GameBalance.get_number("result_lead_speed") * TICK
		_step(animator, 1)
		if i > 60:
			reach = maxf(reach, absf(animator.hoof_offsets[0].z))
			lifted = maxf(lifted, animator.hoof_offsets[0].y)
	check(reach > GameBalance.get_number("gait_step_reach") * 0.85, "led-out loser takes full strides (reach %.3f)" % reach)
	check(lifted > GameBalance.get_number("gait_hoof_lift") * 0.85, "led-out loser lifts its hooves (lift %.3f)" % lifted)
	_reset(buffalo, animator)

func _test_turn_and_teleport(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	_reset(buffalo, animator)
	for i in 30:
		buffalo.rotation.y = wrapf(buffalo.rotation.y + 0.1, -PI, PI)
		_step(animator, 1)
	check(animator.turn_rate > 3.0 and animator.basis.get_euler().z > 0.0, "turning left leans into the turn")
	_reset(buffalo, animator)
	_step(animator, 10)
	buffalo.position = Vector3(10.0, 0.0, 0.0)
	_step(animator, 1)
	check(animator.speed < 0.01, "a teleport (respawn) does not register as movement")


func _test_result(winner: BuffaloAnimator, loser: BuffaloAnimator) -> void:
	_reset(winner.buffalo, winner)
	_reset(loser.buffalo, loser)
	arena.finished = true
	arena.winner_slot = winner.buffalo.slot
	var highest := 0.0
	for i in 120:
		winner.sample_motion(TICK)
		winner.update_pose(TICK)
		loser.sample_motion(TICK)
		loser.update_pose(TICK)
		highest = maxf(highest, winner.position.y)
	check(winner.victory_weight > 0.8 and highest > 0.1, "winner hops in celebration")
	check(loser.defeat_weight > 0.8 and loser.basis.get_euler().x < 0.0, "loser hangs its head")
	arena.finished = false
	arena.winner_slot = 0


func _test_pause(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	_reset(buffalo, animator)
	arena.paused = true
	var before := animator.time
	animator._process(TICK)
	check(is_equal_approx(animator.time, before), "pose freezes while the match is paused")
	arena.paused = false


# No gait step in progress and every hoof on the dirt (the nose-down brace bends the legs).
func _hooves_planted(animator: BuffaloAnimator) -> bool:
	for leg in 4:
		if animator.hoof_offsets[leg].length() > 0.001 or absf(animator.hoof_position(leg).y) > 0.02:
			return false
	return true


func _legs_at_rest(animator: BuffaloAnimator) -> bool:
	for leg in 4:
		if animator.hoof_offsets[leg].length() > 0.001:
			return false
	for bone in animator.leg_skeleton.get_bone_count():
		if animator.leg_skeleton.get_bone_pose_rotation(bone).get_angle() > 0.002:
			return false
	return true
