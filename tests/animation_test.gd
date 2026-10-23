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
	_test_walk(buffalo, animator)
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
	check(buffalo.get_node("Collision").position.is_equal_approx(Vector3(0.0, 1.0, 0.0)), "collision shape is not animated")
	buffalo.state = Buffalo.State.NORMAL


func _pose_for(buffalo: Buffalo, animator: BuffaloAnimator, state: Buffalo.State, progress := 0.5) -> void:
	_reset(buffalo, animator)
	_step(animator, 60)
	buffalo.state = state
	buffalo.state_duration = 0.2
	buffalo.state_time = 0.2 * progress
	_step(animator, 30)


func _test_state_poses(buffalo: Buffalo, animator: BuffaloAnimator) -> void:
	_pose_for(buffalo, animator, Buffalo.State.HORN_STARTUP)
	check(animator.pose_pitch < deg_to_rad(-5.0) and animator.pose_offset.z > 0.05, "HORN startup: head dips and body winds back")
	_pose_for(buffalo, animator, Buffalo.State.HORN_ACTIVE, 0.0)
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
	arena.active_clash = {"a": arena.player, "b": arena.opponent, "time": 0.0, "balance": 80.0}
	buffalo.state = Buffalo.State.CLASH
	_step(animator, 60)
	check(animator.pose_offset.z < -0.1, "CLASH: the winning side leans in")
	arena.active_clash = {"a": arena.opponent, "b": arena.player, "time": 0.0, "balance": 80.0}
	_step(animator, 60)
	check(animator.pose_offset.z > 0.1, "CLASH: the losing side is pushed back")
	arena.active_clash.clear()
	buffalo.state = Buffalo.State.NORMAL


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
