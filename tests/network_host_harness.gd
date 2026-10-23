extends SceneTree

var manager: Node
var failures := 0
var received_client_action := false
var pause_requests: Array[bool] = []
var received_client_resume := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	manager = root.get_node("NetworkManager")
	manager.lobby_ready.connect(_on_lobby_ready)
	manager.input_received.connect(_on_input_received)
	manager.pause_request_received.connect(_on_pause_request)
	manager.status_changed.connect(func(message: String): print("HOST STATUS: ", message))
	var result: Error = manager.host(47931)
	check(result == OK, "host binds test port")
	await create_timer(5.0).timeout
	check(received_client_action, "host receives reliable client HORN action")
	check(pause_requests.size() >= 2 and pause_requests[0] and not pause_requests[1], "host receives pause and resume requests")
	check(received_client_resume, "host receives client input after resume")
	manager.leave()
	print("NETWORK HOST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _on_lobby_ready() -> void:
	manager.send_snapshot({"phase": "READY", "tick": 1})


func _on_input_received(slot: int, payload: Dictionary) -> void:
	if slot == 2 and bool(payload.get("horn", false)):
		received_client_action = true
	elif slot == 2 and bool(payload.get("move_y", 0.0)) and not bool(payload.get("horn", false)):
		received_client_resume = true


func _on_pause_request(_peer_id: int, requested_state: bool) -> void:
	pause_requests.append(requested_state)
	manager.answer_pause(true)
