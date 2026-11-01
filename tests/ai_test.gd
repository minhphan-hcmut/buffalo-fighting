extends SceneTree

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
	var controller: Node = arena.ai
	check(controller != null, "solo match creates AI controller")
	check(controller.profile == &"EASY", "L01 selects EASY profile")
	var frame: InputFrame = controller.build_input(0.7)
	check(frame.player_slot == 2, "AI emits slot 2 InputFrame")
	check(frame.camera_yaw is float, "AI supplies facing intent through camera yaw")
	check(controller.state >= 0 and controller.state <= 5, "AI uses declared FSM state")
	controller.profile = &"HARD"
	var next_frame: InputFrame = controller.build_input(0.3)
	check(next_frame is InputFrame, "HARD profile still produces standard InputFrame")
	arena.free()
	await _test_decision_behaviour()
	for profile in ["EASY", "NORMAL", "HARD"]:
		await _test_not_glued(profile)
		await _test_recover_at_wall(profile)
		await _test_match_finishes(profile)
	print("AI TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _profile(name: String) -> Dictionary:
	var file := FileAccess.open("res://data/ai_profiles.json", FileAccess.READ)
	var profiles: Dictionary = JSON.parse_string(file.get_as_text())
	return profiles[name]


func _gap(arena: MatchController) -> float:
	return ArenaBounds.head_gap(arena.opponent, arena.player)


func _test_decision_behaviour() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	var ai: Node = arena.ai
	var tick := 1.0 / 60.0

	# GUARD is held for the whole decision window, not a single tick.
	ai.profile = &"NORMAL"
	ai.profile_data = _profile("NORMAL")
	arena.player.position = Vector3.ZERO
	arena.opponent.position = Vector3(3.0, 0.0, 0.0)
	arena.player.state = Buffalo.State.HORN_STARTUP
	arena.player.attack_kind = &"HORN"
	arena.player.facing = Vector3.RIGHT
	arena.opponent.state = Buffalo.State.NORMAL
	ai.decision_time = 0.0
	var first: InputFrame = ai.build_input(tick)
	var second: InputFrame = ai.build_input(tick)
	check(first.guard_held and second.guard_held, "AI GUARD is held beyond the decision tick")
	check(not second.horn_pressed and not second.dash_pressed, "edge buttons are only sent on the decision tick")

	# RECOVER has hysteresis: enter below 25 STAMINA, stay until above 60.
	arena.player.state = Buffalo.State.NORMAL
	arena.player.attack_kind = &"NONE"
	ai.recovering = false
	arena.opponent.stamina = 20.0
	ai.decision_time = 0.0
	ai.build_input(tick)
	check(ai.state == ai.State.RECOVER, "AI enters RECOVER below recover_enter")
	arena.opponent.stamina = 40.0
	ai.decision_time = 0.0
	ai.build_input(tick)
	check(ai.state == ai.State.RECOVER, "AI stays in RECOVER between enter and exit thresholds")
	arena.opponent.stamina = 61.0
	ai.decision_time = 0.0
	ai.build_input(tick)
	check(ai.state != ai.State.RECOVER, "AI leaves RECOVER above recover_exit")

	# Never presses HORN while it cannot afford or use it.
	arena.opponent.stamina = 100.0
	arena.opponent.horn_cooldown = 0.5
	arena.opponent.position = Vector3(2.2, 0.0, 0.0)
	arena.opponent.rotation.y = PI / 2.0
	arena.opponent.facing = Vector3.LEFT
	ai.decision_time = 0.0
	var cooling: InputFrame = ai.build_input(tick)
	check(not cooling.horn_pressed, "AI does not press HORN during cooldown")

	arena.free()


# RECOVER against the fence: the AI walks along it until it is at least 4 m from the player.
func _test_recover_at_wall(profile: String) -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	var ai: Node = arena.ai
	ai.profile = StringName(profile)
	ai.profile_data = _profile(profile)
	arena.player.position = Vector3(0.0, 0.0, 6.9)
	arena.opponent.position = Vector3(0.0, 0.0, 9.9)
	arena.opponent.rotation.y = 0.0
	arena.opponent.stamina = 5.0
	var tick := 1.0 / 60.0
	var best := 0.0
	for i in 180:
		arena._physics_process(tick)
		best = maxf(best, arena.player.global_position.distance_to(arena.opponent.global_position))
	check(best >= 4.0, "%s AI recovering at the fence reaches 4 m from the player in 3 s (best %.2f)" % [profile, best])
	arena.free()


# 10 s against an idle player: only ticks with a committed/active attack may stay at gap < 0.05.
# Cooldown and low STAMINA do not excuse sticking to the player.
func _test_not_glued(profile: String) -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	var ai: Node = arena.ai
	ai.profile = StringName(profile)
	ai.profile_data = _profile(profile)
	arena.opponent.position = Vector3(6.0, 0.0, 0.0)
	var glued_ticks := 0
	var worst_glued := 0
	for i in 600:
		arena._physics_process(1.0 / 60.0)
		var attacking: bool = arena.opponent.is_committed() or arena.opponent.is_attack_active()
		if _gap(arena) < 0.05 and not attacking:
			glued_ticks += 1
			worst_glued = maxi(worst_glued, glued_ticks)
		else:
			glued_ticks = 0
	check(worst_glued <= 60, "%s AI is not glued at gap < 0.05 for over 1 s (worst %d ticks)" % [profile, worst_glued])
	arena.free()


# Every profile must play a full 90 s match against an idle player to an end by FLEE or TIME.
func _test_match_finishes(profile: String) -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	var ai: Node = arena.ai
	ai.profile = StringName(profile)
	ai.profile_data = _profile(profile)
	var ticks := 0
	while not arena.finished and ticks < 6000:
		arena._physics_process(1.0 / 60.0)
		ticks += 1
	check(arena.finished and arena.end_reason in [&"FLEE", &"TIME"], "%s AI match ends by FLEE or TIME (%s after %.1f s)" % [profile, arena.end_reason, ticks / 60.0])
	arena.free()
