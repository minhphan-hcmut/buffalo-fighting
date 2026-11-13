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
	await _test_negative_controls()
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
	ai.profile_data["parry_chance"] = 0.0 # Isolate the existing held-GUARD check.
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


const ESCAPE_GAP := 0.3
const ESCAPE_GRACE_S := 0.5


## Stand-in AI for the negative controls: always sends the same move.
class FakeAI extends Node:
	var move := Vector2.ZERO

	func build_input(_delta: float) -> InputFrame:
		var frame := InputFrame.new(2)
		frame.move = move
		frame.camera_yaw = PI / 2.0 # toward the player at the origin
		return frame


func _face_off(arena: MatchController) -> void:
	arena.player.position = Vector3.ZERO
	arena.player.rotation.y = -PI / 2.0
	arena.player.facing = Vector3.RIGHT
	arena.player.velocity = Vector3.ZERO
	arena.opponent.position = Vector3(2.95, 0.0, 0.0)
	arena.opponent.rotation.y = PI / 2.0
	arena.opponent.facing = Vector3.LEFT
	arena.opponent.camera_yaw = PI / 2.0
	arena.opponent.velocity = Vector3.ZERO


## Puts the buffaloes face to face at head_gap ~0.05 eight times, with the AI unable to attack
## ("cooldown": HORN/DASH cooldown held above zero; "stamina": STAMINA held at 15). After each
## face-off the gap must reach ESCAPE_GAP within `deadline_s`. Also needs >= 30 uncommitted ticks at
## gap < 0.1, so a run where the AI was never close cannot pass. Returns {"ok", "near", "failed",
## "worst_escape_s"}.
func _escape_check(arena: MatchController, deadline_s: float, scenario: String) -> Dictionary:
	var deadline_ticks := int(ceil(deadline_s * 60.0))
	var interval := deadline_ticks + 6
	var near_ticks := 0
	var failed := 0
	var worst_escape := 0.0
	for faceoff in 8:
		_face_off(arena)
		var escaped_tick := -1
		for tick in interval:
			if scenario == "cooldown":
				arena.opponent.horn_cooldown = 1.0
				arena.opponent.dash_cooldown = 1.0
			else:
				arena.opponent.stamina = 15.0
			arena._physics_process(1.0 / 60.0)
			var attacking: bool = arena.opponent.is_committed() or arena.opponent.is_attack_active()
			var gap := _gap(arena)
			if gap < 0.1 and not attacking:
				near_ticks += 1
			if escaped_tick < 0 and tick < deadline_ticks and gap >= ESCAPE_GAP:
				escaped_tick = tick + 1
		if escaped_tick < 0:
			failed += 1
		else:
			worst_escape = maxf(worst_escape, escaped_tick / 60.0)
	return {"ok": near_ticks >= 30 and failed == 0, "near": near_ticks, "failed": failed, "worst_escape_s": worst_escape}


func _new_arena() -> MatchController:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	return arena


func _test_not_glued(profile: String) -> void:
	for scenario in ["cooldown", "stamina"]:
		var arena := await _new_arena()
		var ai: Node = arena.ai
		ai.profile = StringName(profile)
		ai.profile_data = _profile(profile)
		if scenario == "stamina":
			# RECOVER would make the AI retreat for another reason; isolate the "cannot attack" path.
			ai.profile_data["recover_enter"] = 0.0
		var deadline := float(ai.profile_data["reaction_s"]) + ESCAPE_GRACE_S
		_face_off(arena)
		check(absf(_gap(arena) - 0.05) < 0.02, "%s/%s: setup starts at head_gap ~0.05 (%.3f)" % [profile, scenario, _gap(arena)])
		var result := _escape_check(arena, deadline, scenario)
		print("ESCAPE %s/%s: slowest escape to gap %.1f took %.2f s (deadline %.2f s), %d ticks close" % [profile, scenario, ESCAPE_GAP, result["worst_escape_s"], deadline, result["near"]])
		check(int(result["near"]) >= 30, "%s/%s: AI really was close without attacking (%d ticks at gap < 0.1)" % [profile, scenario, result["near"]])
		check(int(result["failed"]) == 0, "%s/%s: AI reaches gap %.1f within reaction_s + %.1f s after every face-off" % [profile, scenario, ESCAPE_GAP, ESCAPE_GRACE_S])
		arena.free()


# The check above must be able to fail: an AI that stands still and one that always walks forward.
func _test_negative_controls() -> void:
	for control in [["stands still", Vector2.ZERO], ["always walks forward", Vector2(0.0, -1.0)]]:
		var arena := await _new_arena()
		var fake := FakeAI.new()
		fake.move = control[1]
		arena.remove_child(arena.ai)
		arena.ai.free()
		arena.add_child(fake)
		arena.ai = fake
		var result := _escape_check(arena, float(_profile("EASY")["reaction_s"]) + ESCAPE_GRACE_S, "cooldown")
		check(not bool(result["ok"]) and int(result["failed"]) > 0, "negative control: an AI that %s fails the escape check (%d of 8 face-offs not escaped)" % [control[0], result["failed"]])
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
	while not arena.finished and ticks < 5400:
		arena._physics_process(1.0 / 60.0)
		ticks += 1
	check(arena.finished and arena.end_reason in [&"FLEE", &"TIME"], "%s AI match ends by FLEE or TIME within 5400 ticks (%s after %.1f s)" % [profile, arena.end_reason, ticks / 60.0])
	arena.free()
