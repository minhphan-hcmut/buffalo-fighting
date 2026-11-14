extends SceneTree
## Same script runs standalone contract checks, then as --host/--client through run_pair.

const PORT := 47933
const DT := 1.0 / 60.0
var failures := 0
var arena: MatchController
var manager: Node
var received_parry: InputFrame
var parry_actions := 0
var saw_parry := false
var saw_counter := false
var frozen: Array[int] = []
var final_snapshot: Dictionary = {}


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	manager = root.get_node("NetworkManager")
	var args := OS.get_cmdline_user_args()
	if not args.has("--host") and not args.has("--client"):
		check(manager._neutral_input().has("parry"), "transport neutral input includes PARRY")
		var decoded := MatchNetwork.payload_to_frame({"parry": true, "seq": 7})
		check(decoded.parry_pressed and decoded.seq == 7, "LAN PARRY contract")
		quit(0 if failures == 0 else 1)
		return
	create_timer(25.0).timeout.connect(func(): push_error("LAN readability timed out"); quit(1))
	if args.has("--host"):
		check(manager.host(PORT) == OK, "host binds readability port")
	else:
		check(manager.join("127.0.0.1", PORT) == OK, "client connects readability port")
	await manager.lobby_ready
	SessionState.mode = &"LAN"
	arena = load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.start_playing()
	if args.has("--host"):
		await _host()
	else:
		await _client()
	arena.free()
	manager.leave()
	print("READABILITY LAN FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _host() -> void:
	manager.input_received.connect(func(_slot: int, payload: Dictionary):
		if bool(payload.get("parry", false)):
			parry_actions += 1
			received_parry = MatchNetwork.payload_to_frame(payload))
	var a := arena.player
	var b := arena.opponent
	a.position = Vector3.ZERO
	b.position = Vector3(0, 0, -2.9)
	a.rotation.y = 0.0
	a.facing = Vector3.FORWARD
	b.rotation.y = PI
	b.facing = Vector3.BACK
	while received_parry == null:
		manager.send_snapshot(arena.get_snapshot())
		await create_timer(0.05).timeout
	check(received_parry.seq > 0, "host receives reliable sequenced G from client")
	a.start_horn()
	a.advance_state(a.state_duration)
	arena.simulate_tick(DT, InputFrame.new(1), received_parry)
	check(a.state == Buffalo.State.STUNNED and b.spirit == 100.0 and b.counter_window > 0.0, "host resolves client G as PARRY")
	check(arena.hitstop_ticks == 6, "host parry hitstop is 6")
	await _publish()
	for i in 6:
		arena.simulate_tick(DT, InputFrame.new(1), InputFrame.new(2))
		await _publish()
	var counter := InputFrame.new(2)
	counter.camera_yaw = PI
	counter.horn_pressed = true
	for i in 5:
		arena.simulate_tick(DT, InputFrame.new(1), counter if i == 0 else _idle_b())
		await _publish()
	check(a.spirit == 77.0 and b.spirit == 100.0 and arena.hitstop_ticks == 6, "host counter deals 23 and freezes 6 ticks")
	check(parry_actions == 1, "reliable PARRY edge is consumed once")
	manager.send_event({"type": "READABILITY_FINAL", "snapshot": arena.get_snapshot()})
	await create_timer(0.5).timeout


func _idle_b() -> InputFrame:
	var input := InputFrame.new(2)
	input.camera_yaw = PI
	return input


func _publish() -> void:
	manager.send_snapshot(arena.get_snapshot())
	await create_timer(0.06).timeout


func _client() -> void:
	manager.snapshot_received.connect(func(snapshot: Dictionary):
		if snapshot.has("hitstop_ticks") and arena.player.state == Buffalo.State.STUNNED and arena.opponent.counter_window > 0.0:
			saw_parry = true
			frozen.append(arena.hitstop_ticks))
	manager.event_received.connect(func(event: Dictionary):
		if event.get("type") == "COMBAT" and event.get("event") == "PARRY_SUCCESS":
			saw_parry = true
		if event.get("type") == "COMBAT" and event.get("event") == "COUNTER_HIT":
			saw_counter = true
		if event.get("type") == "READABILITY_FINAL":
			final_snapshot = event["snapshot"])
	var input := _idle_b()
	input.parry_pressed = true
	input.seq = 1
	arena.lan.upload_input(1.0 / 30.0, input)
	while final_snapshot.is_empty():
		await physics_frame
	await create_timer(0.1).timeout
	check(saw_parry and saw_counter, "client receives reliable PARRY and COUNTER events")
	check(frozen == [6, 5, 4, 3, 2, 1, 0], "client displays exact host frozen tick countdown: %s" % str(frozen))
	var expected: Array = final_snapshot["players"]
	check(arena.player.spirit == float(expected[0]["spirit"]) and arena.opponent.spirit == float(expected[1]["spirit"]), "client and host SPIRIT agree")
	check(arena.player.spirit == 77.0 and arena.opponent.spirit == 100.0, "client result is 77/100 after parry counter")
	check(arena.hitstop_ticks == int(final_snapshot["hitstop_ticks"]) and arena.hitstop_ticks == 6, "client and host final hitstop agree")
	check(arena.opponent.counter_attack == bool(expected[1]["counter_attack"]) and arena.opponent.counter_window == 0.0, "client displays host counter and closed window")
	var before := arena.get_snapshot()
	arena.simulate_tick(DT, InputFrame.new(1), InputFrame.new(2))
	check(arena.get_snapshot() == before, "client cannot advance authoritative simulation")
