extends SceneTree
## Parry drills: after a parry stun ends, the drill attacker rests before attacking again,
## so the stun reads clearly in the Sân tập (owner bug 2026-11-16).

const DT := 1.0 / 60.0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)


func run() -> void:
	var profiles := DataFile.load_json("res://data/ai_profiles.json")
	for drill: StringName in [&"horn", &"dash"]:
		SessionState.mode = &"SOLO"
		SessionState.training = true
		SessionState.drill_id = drill
		var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
		root.add_child(arena)
		current_scene = arena
		for i in 5:
			await process_frame
		arena.set_physics_process(false)
		while arena.phase != &"PLAYING":
			arena._physics_process(DT)
		var opponent := arena.opponent
		var profile: Dictionary = profiles["DRILL_" + String(drill).to_upper()]
		var rest := float(profile.get("post_stun_rest_s", 0.0))
		check(rest > 0.0, "%s drill defines post_stun_rest_s" % drill)
		# Stun the drill attacker the moment it commits to an attack, i.e. when it is in range.
		var attacking := false
		for i in 60 * 10:
			arena._physics_process(DT)
			if opponent.state in [Buffalo.State.HORN_STARTUP, Buffalo.State.DASH_ACTIVE]:
				attacking = true
				break
		check(attacking, "%s drill attacks before the stun" % drill)
		opponent.apply_stun(GameBalance.get_number("parry_stun_horn_s"), Vector3.ZERO)
		opponent.horn_cooldown = 0.0
		opponent.dash_cooldown = 0.0
		while opponent.state == Buffalo.State.STUNNED:
			arena._physics_process(DT)
		var attacked_early := false
		var elapsed := 0.0
		while elapsed < rest - 2.0 * DT:
			arena._physics_process(DT)
			elapsed += DT
			attacked_early = attacked_early or opponent.state in [Buffalo.State.HORN_STARTUP, Buffalo.State.HORN_ACTIVE, Buffalo.State.DASH_ACTIVE]
		check(not attacked_early, "%s drill does not attack within %.2f s after a stun" % [drill, rest])
		var attacked_later := false
		for i in 60 * 6:
			arena._physics_process(DT)
			attacked_later = attacked_later or opponent.state in [Buffalo.State.HORN_STARTUP, Buffalo.State.DASH_ACTIVE]
			if attacked_later:
				break
		check(attacked_later, "%s drill resumes attacking after the rest" % drill)
		arena.queue_free()
		await process_frame
	SessionState.training = false
	SessionState.return_to_menu()
	print("TRAINING PARRY REST: %d failures" % failures)
	quit(0 if failures == 0 else 1)
