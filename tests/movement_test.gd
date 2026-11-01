extends SceneTree

const TICK := 1.0 / 60.0

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	var buffalo := arena.player
	var max_step := GameBalance.get_angle("turn_rate_deg_s") * TICK

	# Turning toward a new camera yaw, capped per tick.
	_reset(buffalo)
	var frame := InputFrame.new(1)
	frame.camera_yaw = 2.0
	buffalo.begin_input(frame)
	check(is_equal_approx(buffalo.camera_yaw, 2.0), "begin_input copies frame.camera_yaw")
	var before := buffalo.rotation.y
	buffalo.update_facing(TICK)
	check(buffalo.rotation.y > before, "body turns toward the new frame.camera_yaw")
	check(absf(buffalo.rotation.y - before) <= max_step + 0.0001, "single-tick turn is capped at turn_rate_deg_s")
	check(is_equal_approx(absf(buffalo.rotation.y - before), max_step), "large yaw error turns by exactly the cap")
	for i in 60:
		buffalo.begin_input(frame)
		buffalo.update_facing(TICK)
	check(absf(angle_difference(buffalo.rotation.y, 2.0)) < 0.0001, "body converges on the target yaw")
	check(buffalo.forward().distance_to(Vector3(-sin(2.0), 0.0, -cos(2.0))) < 0.001, "facing vector follows rotation")

	# Turning the short way across the +/-PI seam.
	_reset(buffalo)
	buffalo.rotation.y = 3.0
	frame.camera_yaw = -3.0
	buffalo.begin_input(frame)
	before = buffalo.rotation.y
	buffalo.update_facing(TICK)
	check(absf(angle_difference(before, buffalo.rotation.y)) <= max_step + 0.0001, "wrap-around turn stays within the cap")
	check(angle_difference(before, buffalo.rotation.y) > 0.0, "wrap-around turn takes the short way")
	check(buffalo.rotation.y >= -PI and buffalo.rotation.y <= PI, "rotation stays wrapped to [-PI, PI] across the seam")
	for i in 600:
		frame.camera_yaw = wrapf(frame.camera_yaw + 0.1, -PI, PI)
		buffalo.begin_input(frame)
		buffalo.update_facing(TICK)
	check(buffalo.rotation.y >= -PI and buffalo.rotation.y <= PI, "rotation stays wrapped after many full turns")

	# AI-supplied yaw turns the body through the same path.
	_reset(buffalo)
	var ai_frame := InputFrame.new(1)
	ai_frame.camera_yaw = -1.0
	buffalo.begin_input(ai_frame)
	before = buffalo.rotation.y
	buffalo.update_facing(TICK)
	check(buffalo.rotation.y < before, "AI-supplied yaw turns the body")
	check(absf(buffalo.rotation.y - before) <= max_step + 0.0001, "AI turn is capped at turn_rate_deg_s")

	# Facing is locked in committed states.
	_reset(buffalo)
	frame.camera_yaw = 2.0
	buffalo.begin_input(frame)
	buffalo.start_horn()
	before = buffalo.rotation.y
	buffalo.begin_input(frame)
	buffalo.update_facing(TICK)
	check(buffalo.state == Buffalo.State.HORN_STARTUP and is_equal_approx(buffalo.rotation.y, before), "facing locked during HORN startup")
	buffalo.advance_state(GameBalance.get_number("horn_startup_s") + 0.001)
	buffalo.begin_input(frame)
	buffalo.update_facing(TICK)
	check(buffalo.state == Buffalo.State.HORN_ACTIVE and is_equal_approx(buffalo.rotation.y, before), "facing locked during HORN active")

	_reset(buffalo)
	buffalo.begin_input(frame)
	buffalo.start_dash()
	before = buffalo.rotation.y
	buffalo.begin_input(frame)
	buffalo.update_facing(TICK)
	check(buffalo.state == Buffalo.State.DASH_ACTIVE and is_equal_approx(buffalo.rotation.y, before), "facing locked during DASH active")

	# Knockback decays every stunned tick with no input.
	_reset(buffalo)
	var impulse := Vector3(0.0, 0.0, 8.3)
	buffalo.apply_stun(10.0, impulse)
	var idle := InputFrame.new(1)
	var previous := buffalo.knockback.length()
	var decayed := true
	var strictly := true
	var reached_zero := false
	for i in 60:
		buffalo.begin_input(idle)
		buffalo.simulate_movement(TICK, Vector3.ZERO, 1.0)
		var speed := buffalo.knockback.length()
		if previous > 0.0:
			strictly = strictly and speed < previous
		decayed = decayed and speed <= previous
		previous = speed
		if speed <= 0.0001:
			reached_zero = true
			break
	check(buffalo.state == Buffalo.State.STUNNED, "buffalo remains STUNNED during knockback test")
	check(strictly, "knockback speed strictly decreases each stunned tick")
	check(decayed and reached_zero, "knockback decays to rest")

	_test_separate(arena)
	print("MOVEMENT TEST FAILURES: ", failures)
	quit(failures)


# Overlapping bodies lose the velocity component pointing into each other, keep the tangent.
func _test_separate(arena: MatchController) -> void:
	var a := arena.player
	var b := arena.opponent
	_reset(a)
	_reset(b)
	a.position = Vector3(-0.5, 0.0, 0.0)
	b.position = Vector3(0.5, 0.0, 0.0)
	a.velocity = Vector3(6.0, 0.0, 2.0)
	b.velocity = Vector3(-4.0, 0.0, -1.0)
	ArenaBounds.separate(a, b)
	check(a.velocity.x <= 0.0001 and b.velocity.x >= -0.0001, "separate removes velocity pointing into the other body")
	check(is_equal_approx(a.velocity.z, 2.0) and is_equal_approx(b.velocity.z, -1.0), "separate keeps the tangential velocity")
	check(float(ArenaBounds.deepest_contact(a, b)["depth"]) <= 0.001, "separate leaves no overlap")
	# A buffalo with knockback keeps its velocity.
	_reset(a)
	_reset(b)
	a.position = Vector3(-0.5, 0.0, 0.0)
	b.position = Vector3(0.5, 0.0, 0.0)
	a.velocity = Vector3(6.0, 0.0, 0.0)
	b.apply_stun(0.3, Vector3(-8.0, 0.0, 0.0))
	ArenaBounds.separate(a, b)
	check(is_equal_approx(b.velocity.x, -8.0), "separate leaves a knocked-back buffalo untouched")
	check(a.velocity.x <= 0.0001, "separate still cancels the pusher")


func _reset(buffalo: Buffalo) -> void:
	buffalo.reset_combat()
	buffalo.position = Vector3.ZERO
	buffalo.rotation.y = 0.0
	buffalo.facing = Vector3.FORWARD
	buffalo.camera_yaw = 0.0
	buffalo.velocity = Vector3.ZERO
	buffalo.knockback = Vector3.ZERO
