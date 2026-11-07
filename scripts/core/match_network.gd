class_name MatchNetwork
extends RefCounted
## LAN glue for MatchController. The host simulates and broadcasts 30 Hz snapshots; the client
## uploads its input at 30 Hz and interpolates toward the host's positions.

const SEND_INTERVAL := 1.0 / 30.0

var controller: MatchController
var network: Node
## Latest client input on the host (slot 2).
var remote_frame := InputFrame.new(2)
var remote_guard_blocked_until_release := false
var client_pending_input := InputFrame.new(2)
var client_input_accumulator := 0.0
var snapshot_accumulator := 0.0
var remote_targets: Dictionary = {}


func _init(owner: MatchController, manager: Node) -> void:
	controller = owner
	network = manager


func connect_signals() -> void:
	network.input_received.connect(_on_remote_input)
	network.snapshot_received.connect(_on_snapshot_received)
	network.connection_lost.connect(_on_connection_lost)
	network.event_received.connect(_on_event_received)
	network.pause_request_received.connect(controller._on_pause_request_received)
	network.pause_state_changed.connect(controller._on_pause_state_changed)


func is_client() -> bool:
	return not network.is_host


## Host: send the snapshot at most every SEND_INTERVAL.
func broadcast_snapshot(delta: float, snapshot: Dictionary) -> void:
	snapshot_accumulator += delta
	if snapshot_accumulator >= SEND_INTERVAL:
		network.send_snapshot(snapshot)
		snapshot_accumulator = fmod(snapshot_accumulator, SEND_INTERVAL)


## Host: the snapshot that ends the match goes out once and reliably; no snapshot follows RESULT.
func send_result(snapshot: Dictionary) -> void:
	network.send_event({"type": "RESULT", "snapshot": snapshot})


## Client: merge this tick's input (edges are OR-ed so none are lost) and upload at 30 Hz.
func upload_input(delta: float, sampled_frame: InputFrame) -> void:
	client_pending_input.move = sampled_frame.move
	client_pending_input.camera_yaw = sampled_frame.camera_yaw
	client_pending_input.guard_held = sampled_frame.guard_held
	client_pending_input.guard_pressed = client_pending_input.guard_pressed or sampled_frame.guard_pressed
	client_pending_input.horn_pressed = client_pending_input.horn_pressed or sampled_frame.horn_pressed
	client_pending_input.dash_pressed = client_pending_input.dash_pressed or sampled_frame.dash_pressed
	client_pending_input.seq = sampled_frame.seq
	client_input_accumulator += delta
	if client_input_accumulator >= SEND_INTERVAL:
		network.send_input(frame_to_payload(client_pending_input))
		client_pending_input.horn_pressed = false
		client_pending_input.dash_pressed = false
		client_pending_input.guard_pressed = false
		client_input_accumulator = fmod(client_input_accumulator, SEND_INTERVAL)


## Client: ease both buffaloes toward the latest host positions.
func interpolate(delta: float) -> void:
	for slot in remote_targets:
		var actor: Buffalo = controller.player if int(slot) == 1 else controller.opponent
		var target_position: Vector3 = remote_targets[slot]
		actor.global_position = actor.global_position.lerp(target_position, minf(1.0, delta * GameBalance.get_number("net_interp_rate", 18.0)))


static func frame_to_payload(frame: InputFrame) -> Dictionary:
	return {
		"move_x": frame.move.x,
		"move_y": frame.move.y,
		"camera_yaw": frame.camera_yaw,
		"horn": frame.horn_pressed,
		"dash": frame.dash_pressed,
		"guard": frame.guard_held,
		"guard_pressed": frame.guard_pressed,
		"seq": frame.seq
	}


static func payload_to_frame(payload: Dictionary) -> InputFrame:
	var frame := InputFrame.new(2)
	frame.move = Vector2(float(payload.get("move_x", 0.0)), float(payload.get("move_y", 0.0)))
	frame.camera_yaw = float(payload.get("camera_yaw", 0.0))
	frame.horn_pressed = bool(payload.get("horn", false))
	frame.dash_pressed = bool(payload.get("dash", false))
	frame.guard_held = bool(payload.get("guard", false))
	frame.guard_pressed = bool(payload.get("guard_pressed", false))
	frame.seq = int(payload.get("seq", 0))
	return frame


func _on_remote_input(_peer_id: int, payload: Dictionary) -> void:
	if not network.is_host:
		return
	remote_frame = payload_to_frame(payload)
	if controller.phase != &"PLAYING":
		if remote_frame.guard_held:
			remote_guard_blocked_until_release = true
		remote_frame.horn_pressed = false
		remote_frame.dash_pressed = false
		remote_frame.guard_pressed = false
		remote_frame.guard_held = false
	elif remote_guard_blocked_until_release:
		if not remote_frame.guard_held:
			remote_guard_blocked_until_release = false
		else:
			remote_frame.guard_held = false
			remote_frame.guard_pressed = false


func _on_event_received(payload: Dictionary) -> void:
	if payload.get("type") == "RESULT" and payload.get("snapshot") is Dictionary:
		_on_snapshot_received(payload["snapshot"])


func _on_snapshot_received(snapshot: Dictionary) -> void:
	if network.is_host or not is_instance_valid(controller.player):
		return
	controller.phase = StringName(snapshot.get("phase", controller.phase))
	controller.remaining_time = float(snapshot.get("remaining_ms", 0)) / 1000.0
	controller.countdown_time = float(snapshot.get("countdown_ms", controller.countdown_time * 1000.0)) / 1000.0
	var players: Array = snapshot.get("players", [])
	for item: Dictionary in players:
		var slot := int(item.get("slot", 0))
		if slot != 1 and slot != 2:
			continue
		var actor := controller.player if slot == 1 else controller.opponent
		if item.get("position") is Vector2:
			var position: Vector2 = item["position"]
			remote_targets[slot] = Vector3(position.x, actor.global_position.y, position.y)
		actor.spirit = float(item.get("spirit", actor.spirit))
		actor.stamina = float(item.get("stamina", actor.stamina))
		actor.clash_hooked = bool(item.get("hooking", false))
		_apply_facing(actor, item.get("facing"))
		_apply_action(actor, item.get("action"))
	_apply_clash_snapshot(snapshot)
	if controller.phase == &"RESULT" and not controller.finished:
		controller.finished = true
		controller.winner_slot = int(snapshot.get("winner_slot", 0))
		controller.end_reason = StringName(snapshot.get("end_reason", "NONE"))
		if is_instance_valid(controller.hud):
			controller.hud.show_result(controller.winner_slot, controller.end_reason)


## Client: show the action state the host reports (NORMAL, GUARD, STUNNED, FLEE, attacks...).
func _apply_action(actor: Buffalo, value: Variant) -> void:
	if not (value is String or value is StringName):
		return
	var state := Buffalo.state_from_name(StringName(value))
	if state < 0 or state == actor.state:
		return
	actor.state = state as Buffalo.State
	actor.guarding = state == Buffalo.State.GUARD
	actor.state_time = 0.0


## Client: both buffaloes face where the host says they face (also outside CLASH).
func _apply_facing(actor: Buffalo, value: Variant) -> void:
	if not value is Vector2:
		return
	var flat: Vector2 = value
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	actor.facing = Vector3(flat.x, 0.0, flat.y)
	actor.rotation.y = atan2(-flat.x, -flat.y)


## Client: rebuild the CLASH the host is running so the HUD and animator behave as on the host.
func _apply_clash_snapshot(snapshot: Dictionary) -> void:
	var actors := [controller.player, controller.opponent]
	if bool(snapshot.get("clash_active", false)):
		var lock_max := GameBalance.get_number("lock_max_s")
		controller.active_clash = {
			"a": controller.player,
			"b": controller.opponent,
			"time": lock_max - float(snapshot.get("clash_time_left", lock_max)),
			"lock_balance": float(snapshot.get("lock_balance", 0.0))
		}
		controller.player.clash_partner = controller.opponent
		controller.opponent.clash_partner = controller.player
		for actor: Buffalo in actors:
			actor.state = Buffalo.State.CLASH
		return
	controller.active_clash = {}
	for actor: Buffalo in actors:
		actor.clash_partner = null
		# The action in the same snapshot wins; this only covers snapshots without one.
		if actor.state == Buffalo.State.CLASH:
			actor.state = Buffalo.State.NORMAL


func _on_connection_lost() -> void:
	controller.finished = true
	controller.phase = &"RESULT"
	controller.end_reason = &"CONNECTION_LOST"
	if is_instance_valid(controller.hud):
		controller.hud.show_result(0, controller.end_reason)
