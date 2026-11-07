extends SceneTree
## Host half of the two-process LAN CLASH check. Stages a CLASH, then prints what the host sees.
## Run lan_match_client.gd in a second process once this one is listening on port 47932.

const PORT := 47932

var arena: MatchController
var failures := 0
var saw_post_clash_stun := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var manager: Node = root.get_node("NetworkManager")
	manager.host(PORT)
	var timer := create_timer(25.0)
	timer.timeout.connect(func(): print("HOST: timed out waiting for the client"); quit(1))
	await manager.lobby_ready
	SessionState.mode = &"LAN"
	arena = load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	while arena.phase != &"PLAYING":
		await physics_frame
	var a := arena.player
	var b := arena.opponent
	a.position = Vector3(-1.5, 0.0, 0.0)
	b.position = Vector3(1.5, 0.0, 0.0)
	a.rotation.y = -PI / 2.0
	b.rotation.y = PI / 2.0
	a.facing = Vector3.RIGHT
	b.facing = Vector3.LEFT
	a.camera_yaw = a.rotation.y
	b.camera_yaw = b.rotation.y
	a.start_horn()
	b.start_horn()
	var frame := 0
	var clash_seen := false
	var clash_ended := false
	while frame < 360:
		await physics_frame
		frame += 1
		if arena.clash.is_active() and not clash_seen:
			clash_seen = true
			arena.active_clash["lock_balance"] = 70.0
		if clash_seen and not arena.clash.is_active():
			clash_ended = true
		if clash_ended and b.state == Buffalo.State.STUNNED:
			saw_post_clash_stun = true
		if frame % 12 == 0 or (arena.clash.is_active() != clash_seen and frame % 3 == 0):
			print(_line(frame))
	print("HOST FINAL ", _line(frame))
	print("HOST SPIRIT p1=%.0f p2=%.0f" % [a.spirit, b.spirit])
	check(clash_seen, "host entered a CLASH")
	check(clash_ended, "host CLASH ended")
	check(is_equal_approx(a.spirit, 100.0) and is_equal_approx(b.spirit, 86.0), "host final SPIRIT is 100/86")
	check(saw_post_clash_stun, "host loser was STUNNED after the CLASH")
	check(a.state == Buffalo.State.NORMAL and b.state == Buffalo.State.NORMAL, "host final states are NORMAL/NORMAL")
	# End the match on a tick that skips the 30 Hz snapshot slot: RESULT must still reach the client.
	arena.lan.snapshot_accumulator = 0.0
	b.spirit = 0.0
	await physics_frame
	check(arena.phase == &"RESULT" and arena.winner_slot == 1 and arena.end_reason == &"FLEE", "host ends the match: slot 1 wins by FLEE")
	for wait in 30:
		await physics_frame
	root.get_node("NetworkManager").leave()
	print("LAN HOST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _line(frame: int) -> String:
	return "H f=%03d clash=%s lb=%.1f st=%s/%s facing=(%.2f,%.2f)/(%.2f,%.2f) x=%.2f/%.2f spirit=%.0f/%.0f" % [
		frame, arena.clash.is_active(), float(arena.active_clash.get("lock_balance", 0.0)),
		arena.player.state_name(), arena.opponent.state_name(),
		arena.player.facing.x, arena.player.facing.z, arena.opponent.facing.x, arena.opponent.facing.z,
		arena.player.position.x, arena.opponent.position.x, arena.player.spirit, arena.opponent.spirit
	]
