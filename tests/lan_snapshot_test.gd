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
	var lan := MatchNetwork.new(arena, root.get_node("NetworkManager"))
	var player := arena.player
	var opponent := arena.opponent

	# Full payload while a CLASH runs.
	lan._on_snapshot_received(_snapshot(true, 40.0, 1.2))
	check(not arena.active_clash.is_empty(), "client rebuilds the active CLASH")
	check(is_equal_approx(float(arena.active_clash["lock_balance"]), 40.0), "client keeps lock_balance")
	check(is_equal_approx(float(arena.active_clash["time"]), GameBalance.get_number("lock_max_s") - 1.2), "client derives CLASH time from clash_time_left")
	check(player.state == Buffalo.State.CLASH and opponent.state == Buffalo.State.CLASH, "both buffaloes enter CLASH state")
	check(player.clash_partner == opponent and opponent.clash_partner == player, "clash_partner is rebuilt")
	check(player.facing.distance_to(Vector3.RIGHT) < 0.001 and opponent.facing.distance_to(Vector3.LEFT) < 0.001, "facing follows the snapshot")
	check(absf(angle_difference(player.rotation.y, -PI / 2.0)) < 0.001 and absf(angle_difference(opponent.rotation.y, PI / 2.0)) < 0.001, "rotation follows the snapshot facing")
	check(player.clash_hooked and not opponent.clash_hooked, "hook state follows the snapshot")

	# CLASH ended.
	lan._on_snapshot_received(_snapshot(false, 0.0, 0.0))
	check(arena.active_clash.is_empty(), "client clears the CLASH when it ends")
	check(player.state == Buffalo.State.NORMAL and opponent.state == Buffalo.State.NORMAL, "state returns to NORMAL")
	check(player.clash_partner == null and opponent.clash_partner == null, "clash_partner is cleared")

	# Host snapshot right after a CLASH: the loser is STUNNED, the other GUARDs.
	lan._on_snapshot_received(_snapshot(true, 40.0, 1.0))
	var after := _snapshot(false, 0.0, 0.0)
	after["players"][0]["action"] = "STUNNED"
	after["players"][1]["action"] = "GUARD"
	lan._on_snapshot_received(after)
	check(arena.active_clash.is_empty(), "CLASH is gone in the post-CLASH snapshot")
	check(player.state == Buffalo.State.STUNNED, "client keeps STUNNED right after the CLASH ends")
	check(opponent.state == Buffalo.State.GUARD and opponent.guarding, "client shows GUARD right after the CLASH ends")
	var fled := _snapshot(false, 0.0, 0.0)
	fled["players"][0]["action"] = "FLEE"
	lan._on_snapshot_received(fled)
	check(player.state == Buffalo.State.FLEE, "client shows FLEE")
	lan._on_snapshot_received(_snapshot(false, 0.0, 0.0))
	check(player.state == Buffalo.State.NORMAL and opponent.state == Buffalo.State.NORMAL and not opponent.guarding, "NORMAL comes back from the snapshot")
	var odd := _snapshot(false, 0.0, 0.0)
	odd["players"][0]["action"] = "NOT_A_STATE"
	odd["players"][1]["action"] = 7
	lan._on_snapshot_received(odd)
	check(player.state == Buffalo.State.NORMAL and opponent.state == Buffalo.State.NORMAL, "unknown or mistyped action is ignored")

	# Missing fields never crash and never teleport anyone.
	var before := player.global_position
	lan.remote_targets.clear()
	lan._on_snapshot_received({})
	lan._on_snapshot_received({"phase": "PLAYING"})
	lan._on_snapshot_received({"clash_active": true})
	check(not arena.active_clash.is_empty() and is_zero_approx(float(arena.active_clash["lock_balance"])), "clash_active alone uses default lock_balance")
	lan._on_snapshot_received({"players": [{"slot": 1}, {"slot": 3, "position": Vector2(9, 9)}, {}]})
	check(lan.remote_targets.is_empty(), "players without a position leave remote targets alone")
	check(player.global_position.is_equal_approx(before), "sparse snapshot does not move anyone")
	lan._on_snapshot_received({"players": [{"slot": 1, "facing": "bad", "position": Vector2(1, 2)}]})
	check(lan.remote_targets.has(1), "bad facing type is ignored without losing the position")
	arena.free()
	print("LAN SNAPSHOT TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _snapshot(clash_active: bool, lock_balance: float, time_left: float) -> Dictionary:
	return {
		"tick": 10,
		"phase": "PLAYING",
		"remaining_ms": 80000,
		"countdown_ms": 0,
		"winner_slot": 0,
		"end_reason": "NONE",
		"clash_active": clash_active,
		"lock_balance": lock_balance,
		"clash_time_left": time_left,
		"players": [
			{"slot": 1, "position": Vector2(-1.45, 0.0), "facing": Vector2(1.0, 0.0), "spirit": 90.0, "stamina": 70.0, "action": "CLASH" if clash_active else "NORMAL", "hooking": clash_active},
			{"slot": 2, "position": Vector2(1.45, 0.0), "facing": Vector2(-1.0, 0.0), "spirit": 100.0, "stamina": 60.0, "action": "CLASH" if clash_active else "NORMAL", "hooking": false}
		]
	}
