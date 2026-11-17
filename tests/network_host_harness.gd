extends SceneTree
## Real ENet pair: a cached pre-pause frame must never prove resume works.

const DEADLINE_MS := 10000
const SEND_INTERVAL_MS := 33

var manager: Node
var failures := 0
var received_client_action := false
var pause_requests: Array[bool] = []
## State signals are consent only synchronously while answering a real request.
var answering_pause_request := false
var answered_pause_state := false
var accepted_pause := false
var accepted_resume := false
var received_client_resume := false
var latest_sequence := -1
var resume_sequence := -1
var movement_frames := 0
var last_reported_sequence := -1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	manager = root.get_node("NetworkManager")
	manager.input_received.connect(_on_input_received)
	manager.pause_request_received.connect(_on_pause_request)
	manager.pause_state_changed.connect(_on_pause_state_changed)
	manager.status_changed.connect(func(message: String): print("HOST STATUS: ", message))
	var result: Error = manager.host(47931)
	check(result == OK, "host binds test port")
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	var next_snapshot := 0
	while result == OK and Time.get_ticks_msec() < deadline:
		if Time.get_ticks_msec() >= next_snapshot:
			manager.send_snapshot({"phase": _stage(), "tick": latest_sequence})
			next_snapshot = Time.get_ticks_msec() + SEND_INTERVAL_MS
		await process_frame
	check(received_client_action, "host receives reliable client HORN action")
	check(pause_requests.size() == 2 and pause_requests[0] and not pause_requests[1], "host receives pause and resume requests")
	check(accepted_pause and accepted_resume, "host accepts pause then resume")
	check(received_client_resume, "host receives fresh client marker after accepted resume")
	print("HOST INPUT EVIDENCE: movement_frames=", movement_frames, " latest_seq=", latest_sequence, " resume_seq=", resume_sequence, " fresh=", received_client_resume)
	manager.leave()
	print("NETWORK HOST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _stage() -> String:
	if received_client_resume:
		return "COMPLETE"
	if accepted_resume:
		return "RESUMED"
	if accepted_pause:
		return "PAUSED"
	return "ACTION" if received_client_action else "READY"


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _on_input_received(slot: int, payload: Dictionary) -> void:
	if slot != 2:
		return
	var sequence := int(payload.get("seq", -1))
	latest_sequence = maxi(latest_sequence, sequence)
	if not is_zero_approx(float(payload.get("move_y", 0.0))):
		movement_frames += 1
	if sequence != last_reported_sequence:
		print("HOST FRAME: seq=", sequence, " move_x=", payload.get("move_x", 0.0), " move_y=", payload.get("move_y", 0.0), " resumed=", accepted_resume)
		last_reported_sequence = sequence
	if bool(payload.get("horn", false)):
		received_client_action = true
	if accepted_resume and sequence > resume_sequence and is_equal_approx(float(payload.get("move_x", 0.0)), 0.5) and is_equal_approx(float(payload.get("move_y", 0.0)), -1.0) and not bool(payload.get("horn", false)):
		if not received_client_resume:
			print("HOST FRESH MARKER: seq=", sequence, " resume_seq=", resume_sequence)
		received_client_resume = true


func _on_pause_request(_peer_id: int, requested_state: bool) -> void:
	pause_requests.append(requested_state)
	answering_pause_request = true
	answered_pause_state = requested_state
	manager.answer_pause(true)
	answering_pause_request = false


func _on_pause_state_changed(is_paused: bool) -> void:
	if not answering_pause_request or is_paused != answered_pause_state:
		return
	if is_paused and received_client_action:
		accepted_pause = true
	elif not is_paused and accepted_pause and not accepted_resume:
		accepted_resume = true
		resume_sequence = latest_sequence
		print("HOST ACCEPTED RESUME: seq=", resume_sequence)
