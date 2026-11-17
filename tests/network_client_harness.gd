extends SceneTree
## Use host-observed stages, not elapsed sleeps, to drive the real ENet handshake.

const DEADLINE_MS := 10000
const SEND_INTERVAL := 1.0 / 30.0

var manager: Node
var failures := 0
var received_snapshot := false
var pause_states: Array[bool] = []
var host_stage := ""
var deadline := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	manager = root.get_node("NetworkManager")
	manager.snapshot_received.connect(_on_snapshot_received)
	manager.pause_state_changed.connect(_on_pause_state_changed)
	manager.status_changed.connect(func(message: String): print("CLIENT STATUS: ", message))
	var result: Error = manager.join("127.0.0.1", 47931)
	check(result == OK, "client starts localhost connection")
	# join() calls leave(), emitting a reset false that is not an accepted resume.
	pause_states.clear()
	deadline = Time.get_ticks_msec() + DEADLINE_MS
	if result == OK and await _wait_for(func(): return manager.connected and host_stage == "READY", "connected and host READY"):
		manager.send_input({"move_x": 0.0, "move_y": -1.0, "horn": true})
		if await _wait_for(func(): return host_stage == "ACTION", "host observed reliable HORN"):
			manager.request_pause(true)
			if await _wait_for(func(): return pause_states == [true] and host_stage == "PAUSED", "accepted pause"):
				manager.request_pause(false)
				if await _wait_for(func(): return pause_states == [true, false] and host_stage == "RESUMED", "accepted resume"):
					await _stream_after_resume()
	check(received_snapshot, "client receives host-authoritative snapshot")
	check(pause_states == [true, false], "client receives accepted pause/resume")
	check(host_stage == "COMPLETE", "client sees host acknowledge fresh post-resume marker")
	print("CLIENT EVIDENCE: stage=", host_stage, " pause_states=", pause_states)
	manager.leave()
	print("NETWORK CLIENT FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _wait_for(predicate: Callable, description: String) -> bool:
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	var reached := bool(predicate.call())
	check(reached, description)
	return reached


func _stream_after_resume() -> void:
	var omit_marker := OS.get_cmdline_user_args().has("--no-fresh-marker")
	var sent := 0
	while host_stage != "COMPLETE" and manager.connected and Time.get_ticks_msec() < deadline:
		# Negative control still streams old movement: no fresh marker is ever sent.
		manager.send_input({"move_x": 0.0 if omit_marker else 0.5, "move_y": -1.0, "horn": false})
		sent += 1
		await create_timer(SEND_INTERVAL).timeout
	print("CLIENT POST-RESUME STREAM: sent=", sent, " omit_marker=", omit_marker)


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _on_snapshot_received(payload: Dictionary) -> void:
	received_snapshot = true
	host_stage = str(payload.get("phase", ""))


func _on_pause_state_changed(is_paused: bool) -> void:
	# Connection teardown also emits false; it is not handshake acceptance.
	if manager.connected:
		pause_states.append(is_paused)
