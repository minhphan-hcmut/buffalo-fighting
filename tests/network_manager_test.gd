extends SceneTree

var failures := 0
var last_pause_state := false
var last_pause_request := false


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	var manager := root.get_node_or_null("NetworkManager")
	check(manager != null, "NetworkManager autoload exists")
	if manager != null:
		var result: Error = manager.host(47921)
		check(result == OK, "ENet host binds a local port")
		check(manager.is_host and manager.connected, "host authority state is set")
		manager.pause_state_changed.connect(_on_pause_state_changed)
		manager.pause_request_received.connect(_on_pause_request_received)
		manager.request_pause(true)
		check(not last_pause_request, "host pause request is not offered to the host itself")
		manager.answer_pause(true)
		check(not last_pause_state, "host cannot approve its own pause request")
		manager.leave()
		check(not manager.is_host and not manager.connected, "leave closes host state")
	print("NETWORK TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _on_pause_state_changed(is_paused: bool) -> void:
	last_pause_state = is_paused


func _on_pause_request_received(_peer_id: int, requested_pause: bool) -> void:
	last_pause_request = requested_pause
