extends SceneTree

var failures := 0
var host_requests := 0
var client_requests: Array = []
var pause_states: Array[bool] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _escape_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event


func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	check(arena.mode == &"SOLO" and not arena.paused, "arena starts unpaused in SOLO")
	root.push_input(_escape_event())
	check(arena.paused, "Esc during PLAYING pauses in SOLO through the camera rig")
	root.push_input(_escape_event())
	check(not arena.paused, "second Esc resumes in SOLO")
	arena.queue_free()
	await process_frame

	var manager := root.get_node_or_null("NetworkManager")
	check(manager != null, "NetworkManager autoload exists")
	if manager != null:
		_run_network(manager)
	print("PAUSE TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _run_network(manager: Node) -> void:
	manager.pause_request_received.connect(func(peer_id: int, state: bool): client_requests.append([peer_id, state]))
	manager.pause_state_changed.connect(func(state: bool): pause_states.append(state))
	check(manager.host(47941) == OK, "host binds a test port")
	# host() resets state through leave(), which emits pause_state_changed(false).
	pause_states.clear()
	# Pretend a client is connected so the host path behaves as in a full lobby.
	manager._client_peer_id = 2

	manager.request_pause(true)
	check(client_requests.is_empty(), "host request_pause does not emit pause_request_received on the host")
	manager.answer_pause(true)
	check(pause_states.is_empty() and not manager._match_paused, "host cannot approve its own pause request")

	manager._on_pause_answer(2, true)
	check(pause_states == [true], "client accept applies the pause on the host")
	manager.set_pause_state(true)
	check(manager._match_paused, "host-authoritative pause state is applied")

	manager.request_pause(false)
	manager._on_pause_answer(2, false)
	check(manager._match_paused and pause_states.back() == true, "client reject keeps the match paused")

	manager.request_pause(false)
	var states_before := pause_states.size()
	manager._on_pause_answer(3, true)
	check(pause_states.size() == states_before, "answer from a non-client peer is ignored")
	manager._on_pause_answer(2, true)
	check(pause_states.back() == false, "client accept of a resume request unpauses the host")

	# A client request is confirmed by the host.
	manager._pending_pause_state = true
	manager._pending_requester = 2
	manager.answer_pause(true)
	check(pause_states.back() == true, "host accepting a client request applies the pause")

	# Client-side view of a host request.
	manager.leave()
	manager.is_host = false
	manager.connected = true
	client_requests.clear()
	manager._on_host_pause_request(1, true)
	check(client_requests == [[1, true]], "client receives the host's pause request for confirmation")
	manager._on_host_pause_request(3, true)
	check(client_requests.size() == 1, "pause request from a non-host sender is ignored on the client")
	manager.connected = false
	manager.leave()
