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
	print("AI TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _profile(name: String) -> Dictionary:
	var file := FileAccess.open("res://data/ai_profiles.json", FileAccess.READ)
	var profiles: Dictionary = JSON.parse_string(file.get_as_text())
	return profiles[name]


func _gap(arena: MatchController) -> float:
	var offset := arena.opponent.global_position - arena.player.global_position
	offset.y = 0.0
	return offset.length() - GameBalance.get_number("buffalo_radius") * 2.0


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

	# Headless 10 s run against an idle player: the AI must not stay glued while unable to attack.
	ai.profile = &"EASY"
	ai.profile_data = _profile("EASY")
	ai.recovering = false
	arena.player.reset_combat()
	arena.opponent.reset_combat()
	arena.player.position = Vector3.ZERO
	arena.opponent.position = Vector3(6.0, 0.0, 0.0)
	var glued_ticks := 0
	var worst_glued := 0
	for i in 600:
		arena._physics_process(tick)
		var attacking: bool = arena.opponent.state != Buffalo.State.NORMAL or arena.opponent.horn_cooldown > 0.0
		if _gap(arena) < 0.05 and not attacking:
			glued_ticks += 1
			worst_glued = maxi(worst_glued, glued_ticks)
		else:
			glued_ticks = 0
	check(worst_glued <= 60, "AI is not glued at gap < 0.05 for over 1 s while unable to attack")
	arena.free()
