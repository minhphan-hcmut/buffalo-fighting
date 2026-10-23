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
	arena.start_playing()
	var attacker := arena.player
	var defender := arena.opponent
	_set_duel(attacker, defender, 2.0)
	check(attacker.start_horn(), "HORN starts with sufficient stamina")
	check(is_equal_approx(attacker.stamina, 80.0), "HORN deducts its stamina cost")
	attacker.advance_state(GameBalance.get_number("horn_startup_s") + 0.001)
	check(attacker.state == Buffalo.State.HORN_ACTIVE, "HORN enters active phase")
	arena.combat.resolve_attacks()
	check(is_equal_approx(defender.spirit, 82.0), "front HORN hit removes 18 SPIRIT")
	check(defender.state == Buffalo.State.STUNNED, "unblocked HORN applies stun")
	arena.combat.resolve_attacks()
	check(is_equal_approx(defender.spirit, 82.0), "one HORN action hits each target once")

	_reset_duel(attacker, defender, 2.0)
	defender.state = Buffalo.State.GUARD
	defender.guarding = true
	check(attacker.start_horn(), "second HORN starts")
	attacker.advance_state(GameBalance.get_number("horn_startup_s") + 0.001)
	arena.combat.resolve_attacks()
	check(is_equal_approx(defender.spirit, 92.0), "front GUARD reduces HORN SPIRIT loss")
	check(defender.state == Buffalo.State.GUARD, "successful front GUARD prevents stun")

	_reset_duel(attacker, defender, 2.0)
	check(attacker.start_dash(), "DASH starts with sufficient stamina")
	check(is_equal_approx(attacker.stamina, 72.0), "DASH deducts its stamina cost")
	check(is_equal_approx(attacker.velocity.length(), GameBalance.get_number("dash_speed")), "DASH sets authored speed")
	defender.start_horn()
	arena.combat.resolve_attacks()
	check(not arena.active_clash.is_empty(), "committed opposing action creates CLASH")
	check(attacker.state == Buffalo.State.CLASH and defender.state == Buffalo.State.CLASH, "CLASH changes both actors together")
	check(is_zero_approx(attacker.spirit - 100.0) and is_zero_approx(defender.spirit - 100.0), "CLASH causes no initial SPIRIT loss")
	attacker.input_frame = InputFrame.new(1)
	check(is_zero_approx(arena.clash.push_strength(attacker, &"PUSH")), "standing still does not push in CLASH")
	attacker.input_frame.move = Vector2(0.0, -1.0)
	attacker.input_frame.camera_yaw = 0.0
	check(arena.clash.push_strength(attacker, &"PUSH") > 0.0, "holding toward the opponent pushes")
	arena.active_clash["balance"] = 0.0
	arena.clash.start_hook(attacker, defender, &"HOOK")
	arena.clash.start_hook(defender, attacker, &"HOOK")
	arena.clash.advance_hooks(attacker, defender, GameBalance.get_number("lock_hook_startup_s") + 0.01)
	check(is_zero_approx(float(arena.active_clash["balance"])), "simultaneous hooks cancel symmetrically")
	check(not attacker.clash_hooked and not defender.clash_hooked, "simultaneous hook startup clears both hooks")
	arena.clash.apply_loss(defender, 5.0)
	check(defender.state == Buffalo.State.STUNNED, "CLASH loss applies stun")
	arena.clash.end(0.0, &"CLASH_TEST")
	check(defender.state == Buffalo.State.STUNNED, "ending CLASH preserves resulting stun")

	check(arena.get_snapshot().has("players"), "snapshot exposes both player slots")
	arena.free()
	print("COMBAT TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _set_duel(attacker: Buffalo, defender: Buffalo, distance: float) -> void:
	attacker.position = Vector3.ZERO
	defender.position = Vector3(0.0, 0.0, -distance)
	attacker.rotation.y = 0.0
	defender.rotation.y = PI
	attacker.facing = Vector3.FORWARD
	defender.facing = Vector3.BACK
	attacker.active = true
	defender.active = true
	attacker.state = Buffalo.State.NORMAL
	defender.state = Buffalo.State.NORMAL
	attacker.guarding = false
	defender.guarding = false
	attacker.spirit = 100.0
	defender.spirit = 100.0
	attacker.stamina = 100.0
	defender.stamina = 100.0
	attacker.horn_cooldown = 0.0
	attacker.dash_cooldown = 0.0
	defender.horn_cooldown = 0.0
	defender.dash_cooldown = 0.0
	attacker.hit_invulnerability = 0.0
	defender.hit_invulnerability = 0.0
	attacker.hit_targets.clear()
	defender.hit_targets.clear()


func _reset_duel(attacker: Buffalo, defender: Buffalo, distance: float) -> void:
	_set_duel(attacker, defender, distance)
	attacker.attack_kind = &"NONE"
	defender.attack_kind = &"NONE"
	attacker.knockback = Vector3.ZERO
	defender.knockback = Vector3.ZERO
