extends SceneTree

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
	_test_pinned()
	_test_pinned_damage()
	_test_clash_whiff_and_release()
	_test_clash_loss_effects()
	arena.free()
	print("CLASH PINNED TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _fence_position(angle_deg: float) -> Vector3:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	var limit := 1.0 - GameBalance.get_number("buffalo_radius") / minf(rx, rz)
	var angle := deg_to_rad(angle_deg)
	return Vector3(cos(angle) * limit * rx, 0.0, sin(angle) * limit * rz)


func _outward(position: Vector3) -> Vector3:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	return Vector3(position.x / (rx * rx), 0.0, position.z / (rz * rz)).normalized()


func _test_pinned() -> void:
	var target := arena.player
	for angle in [0.0, 45.0, 90.0, 135.0, 180.0, 270.0, 315.0]:
		target.position = _fence_position(angle)
		var outward := _outward(target.position)
		check(ArenaBounds.is_pinned(target, outward), "PINNED at fence angle %d with knockback toward the fence" % int(angle))
		check(not ArenaBounds.is_pinned(target, -outward), "not PINNED at fence angle %d with knockback pointing inward" % int(angle))
	target.position = Vector3.ZERO
	check(not ArenaBounds.is_pinned(target, Vector3.RIGHT), "not PINNED at arena center")
	target.position = Vector3(5.0, 0.0, 3.0)
	check(not ArenaBounds.is_pinned(target, _outward(target.position)), "not PINNED mid-arena with outward knockback")


func _test_pinned_damage() -> void:
	var attacker := arena.opponent
	var target := arena.player
	var base := GameBalance.get_number("horn_damage")
	var multiplier := GameBalance.get_number("pinned_spirit_multiplier")
	for angle in [0.0, 90.0, 200.0]:
		_ready_actor(target, _fence_position(angle))
		_ready_actor(attacker, target.position - _outward(target.position) * 2.0)
		attacker.attack_kind = &"HORN"
		arena.combat.apply_hit(attacker, target)
		check(is_equal_approx(target.spirit, 100.0 - roundi(base * multiplier)), "pinned HORN hit at %d deg deals damage x multiplier" % int(angle))
	_ready_actor(target, Vector3.ZERO)
	_ready_actor(attacker, Vector3(0.0, 0.0, -2.0))
	attacker.attack_kind = &"HORN"
	arena.combat.apply_hit(attacker, target)
	check(is_equal_approx(target.spirit, 100.0 - base), "unpinned HORN hit deals base damage")


func _ready_actor(actor: Buffalo, at: Vector3) -> void:
	actor.position = at
	actor.active = true
	actor.state = Buffalo.State.NORMAL
	actor.guarding = false
	actor.spirit = 100.0
	actor.stamina = 100.0
	actor.hit_invulnerability = 0.0
	actor.hit_targets.clear()
	actor.knockback = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	actor.clash_hooked = false


# Starts a CLASH at the arena center, then plays one tick with the given frames.
func _clash_tick(a_frame: InputFrame, b_frame: InputFrame, a_hooked: bool, b_hooked: bool) -> Dictionary:
	arena.active_clash.clear()
	_ready_actor(arena.player, Vector3(-1.0, 0.0, 0.0))
	_ready_actor(arena.opponent, Vector3(1.0, 0.0, 0.0))
	arena.clash.enter(0.0)
	var a: Buffalo = arena.active_clash["a"]
	var b: Buffalo = arena.active_clash["b"]
	a.clash_hooked = a_hooked
	b.clash_hooked = b_hooked
	a.clash_hook_time = 0.2
	b.clash_hook_time = 0.2
	arena.clash.process(1.0 / 60.0, a_frame, b_frame)
	return {"a": a, "b": b, "ended": arena.active_clash.is_empty()}


func _release_frame() -> InputFrame:
	var frame := InputFrame.new(1)
	frame.guard_pressed = true
	return frame


func _push_frame() -> InputFrame:
	return InputFrame.new(1)


func _hook_frame() -> InputFrame:
	var frame := InputFrame.new(1)
	frame.horn_pressed = true
	return frame


func _test_clash_whiff_and_release() -> void:
	var whiff := GameBalance.get_number("lock_whiff_spirit")
	# Release while the opponent is in hook startup (hook pressed on an earlier tick).
	var r := _clash_tick(_release_frame(), _push_frame(), false, true)
	check(r["ended"] and is_equal_approx(r["b"].spirit, 100.0 - whiff), "A releases during B hook startup: hooker B loses whiff SPIRIT")
	check(is_equal_approx(r["a"].spirit, 100.0), "A releases during B hook startup: releaser A loses nothing")
	r = _clash_tick(_push_frame(), _release_frame(), true, false)
	check(r["ended"] and is_equal_approx(r["a"].spirit, 100.0 - whiff), "B releases during A hook startup: hooker A loses whiff SPIRIT")
	check(is_equal_approx(r["b"].spirit, 100.0), "B releases during A hook startup: releaser B loses nothing")
	# Release against a hook pressed this same tick.
	r = _clash_tick(_release_frame(), _hook_frame(), false, false)
	check(is_equal_approx(r["b"].spirit, 100.0 - whiff) and is_equal_approx(r["a"].spirit, 100.0), "A releases vs same-tick B hook: only B loses")
	r = _clash_tick(_hook_frame(), _release_frame(), false, false)
	check(is_equal_approx(r["a"].spirit, 100.0 - whiff) and is_equal_approx(r["b"].spirit, 100.0), "B releases vs same-tick A hook: only A loses")
	# Release with no hook -> release penalty on the releaser.
	var penalty := GameBalance.get_number("lock_release_spirit_base")
	r = _clash_tick(_release_frame(), _push_frame(), false, false)
	check(r["ended"] and is_equal_approx(r["a"].spirit, 100.0 - penalty) and is_equal_approx(r["b"].spirit, 100.0), "A releases with no hook: A takes release penalty")
	r = _clash_tick(_push_frame(), _release_frame(), false, false)
	check(r["ended"] and is_equal_approx(r["b"].spirit, 100.0 - penalty) and is_equal_approx(r["a"].spirit, 100.0), "B releases with no hook: B takes release penalty")
	# Both release in the same tick -> nobody loses.
	r = _clash_tick(_release_frame(), _release_frame(), false, false)
	check(r["ended"] and is_equal_approx(r["a"].spirit, 100.0) and is_equal_approx(r["b"].spirit, 100.0), "both release same tick: nobody loses")
	r = _clash_tick(_release_frame(), _release_frame(), true, true)
	check(r["ended"] and is_equal_approx(r["a"].spirit, 100.0) and is_equal_approx(r["b"].spirit, 100.0), "both release while hooked: nobody loses")


func _test_clash_loss_effects() -> void:
	var whiff := GameBalance.get_number("lock_whiff_spirit")
	var penalty := GameBalance.get_number("lock_release_spirit_base")
	var knockback := GameBalance.get_number("knockback_speed")
	# A same-tick hook the hooker cannot afford never starts, so the release is penalised instead.
	arena.active_clash.clear()
	_ready_actor(arena.player, Vector3(-1.0, 0.0, 0.0))
	_ready_actor(arena.opponent, Vector3(1.0, 0.0, 0.0))
	arena.clash.enter(0.0)
	arena.opponent.stamina = GameBalance.get_number("horn_cost") - 1.0
	arena.clash.process(1.0 / 60.0, _release_frame(), _hook_frame())
	check(is_equal_approx(arena.player.spirit, 100.0 - penalty) and is_equal_approx(arena.opponent.spirit, 100.0), "release vs unaffordable same-tick hook: releaser takes the penalty")

	# Stun durations per CLASH outcome.
	var r := _clash_tick(_release_frame(), _push_frame(), false, true)
	check(r["b"].state == Buffalo.State.STUNNED and is_equal_approx(r["b"].state_duration, GameBalance.get_number("lock_whiff_stun_s")), "whiffed hooker is STUNNED lock_whiff_stun_s")
	r = _clash_tick(_release_frame(), _push_frame(), false, false)
	check(r["a"].state == Buffalo.State.STUNNED and is_equal_approx(r["a"].state_duration, GameBalance.get_number("lock_release_stun_s")), "penalised releaser is STUNNED lock_release_stun_s")

	# Losing the lock: x1.5 knockback and longer stun, pinned or not.
	arena.active_clash.clear()
	_ready_actor(arena.player, Vector3(-1.0, 0.0, 0.0))
	_ready_actor(arena.opponent, Vector3(1.0, 0.0, 0.0))
	arena.clash.enter(0.0)
	arena.active_clash["balance"] = 99.99
	var push := InputFrame.new(1)
	push.move = Vector2(0.0, -1.0)
	push.camera_yaw = atan2(-1.0, 0.0) # face +X, toward the opponent
	arena.player.input_frame = push
	arena.clash.process(1.0 / 60.0, push, _push_frame())
	var loser := arena.opponent
	check(arena.active_clash.is_empty() and is_equal_approx(loser.spirit, 100.0 - GameBalance.get_number("lock_loss_spirit")), "lock break: loser loses lock_loss_spirit")
	check(is_equal_approx(loser.state_duration, GameBalance.get_number("lock_loss_stun_s")), "lock break: loser is STUNNED lock_loss_stun_s")
	check(is_equal_approx(loser.velocity.length(), knockback * GameBalance.get_number("lock_loss_knockback_multiplier")), "lock break: knockback x lock_loss_knockback_multiplier")

	# Pinned whiff: SPIRIT x pinned multiplier, but knockback is NOT boosted.
	arena.active_clash.clear()
	var fence := _fence_position(0.0)
	_ready_actor(arena.opponent, fence)
	_ready_actor(arena.player, fence - _outward(fence) * 2.0)
	arena.clash.enter(0.0)
	arena.opponent.clash_hooked = true
	arena.opponent.clash_hook_time = 0.2
	arena.clash.process(1.0 / 60.0, _release_frame(), _push_frame())
	check(is_equal_approx(arena.opponent.spirit, 100.0 - whiff * GameBalance.get_number("pinned_spirit_multiplier")), "pinned whiff: SPIRIT loss x pinned multiplier")
	check(is_equal_approx(arena.opponent.velocity.length(), knockback), "pinned whiff: knockback is not multiplied")
