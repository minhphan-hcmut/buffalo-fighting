extends SceneTree

var manager: Node
var failures := 0
var received_snapshot := false
var pause_states: Array[bool] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	manager = root.get_node("NetworkManager")
	manager.lobby_ready.connect(_on_lobby_ready)
	manager.snapshot_received.connect(_on_snapshot_received)
	manager.pause_state_changed.connect(_on_pause_state_changed)
	manager.status_changed.connect(func(message: String): print("CLIENT STATUS: ", message))
	var result: Error = manager.join("127.0.0.1", 47931)
	check(result == OK, "client starts localhost connection")
	# join() resets state through leave(), which emits pause_state_changed(false).
	pause_states.clear()
	await create_timer(0.6).timeout
	print("CLIENT CONNECTED: ", manager.connected)
	if manager.connected:
		manager.send_input({
			"move_x": 0.0,
			"move_y": -1.0,
			"camera_yaw": 0.0,
			"horn": true,
			"dash": false,
			"guard": false,
			"guard_pressed": false,
			"seq": 1
		})
		await create_timer(0.3).timeout
		manager.request_pause(true)
		await create_timer(0.3).timeout
		manager.request_pause(false)
		await create_timer(0.3).timeout
	check(received_snapshot, "client receives host-authoritative snapshot")
	check(pause_states.size() >= 2 and pause_states[0] and not pause_states[1], "client receives accepted pause/resume")
	manager.leave()
	print("NETWORK CLIENT FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _on_lobby_ready() -> void:
	pass


func _on_snapshot_received(_payload: Dictionary) -> void:
	received_snapshot = true


func _on_pause_state_changed(is_paused: bool) -> void:
	pause_states.append(is_paused)
