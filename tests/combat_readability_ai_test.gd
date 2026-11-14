extends SceneTree

const DT := 1.0 / 60.0
var failures := 0
var arena: MatchController


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	arena = load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	var ai: Node = arena.ai
	var profiles := DataFile.load_json("res://data/ai_profiles.json")
	for name in ["EASY", "NORMAL", "HARD"]:
		ai.profile_data = profiles[name]
		var first := _rolls(ai, 314159)
		var again := _rolls(ai, 314159)
		var expected := float(profiles[name]["parry_chance"])
		var ratio := first.count(true) / float(first.size())
		check(first == again, "%s seeded parry choices repeat exactly" % name)
		check(absf(ratio - expected) < 0.025, "%s parry rate %.3f (expected %.2f)" % [name, ratio, expected])
		if name == "EASY":
			check(not first.has(true), "EASY never schedules G")
	for kind in ["HORN", "DASH"]:
		_reset()
		ai.profile_data = profiles["HARD"].duplicate(true)
		ai.profile_data["parry_chance"] = 1.0
		ai.observed_attack = -1
		ai.decision_time = 100.0
		ai.held_move = Vector2.ZERO
		ai.held_guard = false
		if kind == "HORN":
			arena.player.start_horn()
		else:
			arena.player.position.z = 0.6
			arena.player.start_dash()
		var pressed := 0
		for i in 22:
			await physics_frame
			var input: InputFrame = ai.build_input(DT)
			if input.parry_pressed:
				pressed += 1
			arena.opponent.begin_input(input)
			arena.player.advance_state(DT)
			arena.opponent.advance_state(DT)
			if kind == "DASH":
				arena.player.simulate_movement(DT, Vector3.ZERO, 1.0)
			arena.combat.resolve_attacks()
			if arena.player.state == Buffalo.State.STUNNED:
				break
		check(pressed == 1 and arena.player.state == Buffalo.State.STUNNED and arena.opponent.spirit == 100.0, "scheduled %s parry succeeds independently of reaction_s" % kind)
	for name in ["EASY", "NORMAL", "HARD"]:
		_reset()
		ai.profile_data = profiles[name]
		ai.rng.seed = 271828
		ai.decision_time = 100.0
		var counters := 0
		for i in 2000:
			arena.opponent.counter_window = 0.0
			ai.build_input(0.0)
			arena.opponent.counter_window = 0.5
			var input: InputFrame = ai.build_input(0.0)
			if input.horn_pressed:
				counters += 1
		check(absf(counters / 2000.0 - float(profiles[name]["counter_chance"])) < 0.04, "%s counter decision rate %.3f" % [name, counters / 2000.0])
	arena.free()
	print("READABILITY AI FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _reset() -> void:
	arena.active_clash.clear()
	arena.hitstop_ticks = 0
	for actor: Buffalo in [arena.player, arena.opponent]:
		actor.reset_combat()
	arena.player.position = Vector3.ZERO
	arena.opponent.position = Vector3(0, 0, -2.9)
	arena.player.rotation.y = 0.0
	arena.player.facing = Vector3.FORWARD
	arena.opponent.rotation.y = PI
	arena.opponent.facing = Vector3.BACK


func _rolls(ai: Node, seed_value: int) -> Array[bool]:
	_reset()
	ai.rng.seed = seed_value
	ai.observed_attack = -1
	var result: Array[bool] = []
	for i in 4000:
		arena.player.state = Buffalo.State.HORN_STARTUP
		arena.player.attack_kind = &"HORN"
		arena.player.state_time = 0.0
		arena.player.state_duration = 0.25
		arena.player.attack_serial += 1
		ai._observe_attack()
		var picked: bool = ai.parry_delay >= 0.0
		result.append(picked)
		var rng_state: int = ai.rng.state
		ai._observe_attack()
		check_no_reroll(ai.rng.state == rng_state)
	return result


func check_no_reroll(ok: bool) -> void:
	if not ok:
		failures += 1
		push_error("AI rolled twice for one attack")
