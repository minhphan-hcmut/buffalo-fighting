extends Node

signal status_changed(message: String)
signal lobby_ready
signal input_received(peer_id: int, payload: Dictionary)
signal snapshot_received(payload: Dictionary)
signal event_received(payload: Dictionary)
signal connection_lost
signal pause_request_received(peer_id: int, requested_state: bool)
signal pause_state_changed(is_paused: bool)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1
const ENET_CHANNEL_COUNT := 3
const CONNECTION_TIMEOUT_SECONDS := 10.0
const CLIENT_SLOT := 2

var peer: ENetMultiplayerPeer
var is_host := false
var connected := false
var last_input_seq: Dictionary = {}
var last_action_seq: Dictionary = {}
var _client_peer_id := 0
var _connection_deadline := 0.0
var _movement_sequence := 0
var _action_sequence := 0
var _remote_frame: Dictionary = {}
var _pending_pause_state := true
## Peer id (1 = host) that asked for the pending pause change; 0 when none.
var _pending_requester := 0
var _match_paused := false


func _ready() -> void:
	_wire_multiplayer()


func _process(_delta: float) -> void:
	if _connection_deadline > 0.0 and Time.get_ticks_msec() >= _connection_deadline:
		_connection_deadline = 0.0
		if not connected and not is_host:
			_fail_connection("Hết thời gian chờ kết nối (10 giây)")


func _physics_process(_delta: float) -> void:
	if not is_host or _client_peer_id == 0 or _remote_frame.is_empty():
		return
	input_received.emit(CLIENT_SLOT, _remote_frame.duplicate())
	for action_name in ["horn", "dash", "guard_pressed", "hook", "release"]:
		_remote_frame[action_name] = false


func host(port: int = DEFAULT_PORT) -> Error:
	leave()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS, ENET_CHANNEL_COUNT)
	if error != OK:
		peer = null
		status_changed.emit("Không thể mở phòng: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	connected = true
	_wire_multiplayer()
	status_changed.emit("Đang host LAN · port %d · chờ người chơi" % port)
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		status_changed.emit("Hãy nhập địa chỉ IPv4 của máy host")
		return ERR_INVALID_PARAMETER
	leave()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(clean_address, port, ENET_CHANNEL_COUNT)
	if error != OK:
		peer = null
		status_changed.emit("Không thể bắt đầu kết nối: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	connected = false
	_connection_deadline = Time.get_ticks_msec() + int(CONNECTION_TIMEOUT_SECONDS * 1000.0)
	_wire_multiplayer()
	status_changed.emit("Đang kết nối tới %s:%d (tối đa 10 giây)" % [clean_address, port])
	return OK


func leave() -> void:
	_connection_deadline = 0.0
	if peer != null:
		peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	peer = null
	connected = false
	is_host = false
	_client_peer_id = 0
	_movement_sequence = 0
	_action_sequence = 0
	last_input_seq.clear()
	last_action_seq.clear()
	_remote_frame.clear()
	_match_paused = false
	_pending_requester = 0
	pause_state_changed.emit(false)


func request_pause(requested_state: bool = true) -> void:
	if not connected:
		return
	_pending_pause_state = requested_state
	if is_host:
		# The other player must approve: ask the client, never the host itself.
		_pending_requester = 1
		if _client_peer_id > 0 and multiplayer.get_peers().has(_client_peer_id):
			receive_pause_request.rpc_id(_client_peer_id, requested_state)
	else:
		request_pause_rpc.rpc_id(1, requested_state)


## Answers the pending request. The host answers client requests locally; the
## client answers host requests by RPC. A requester never answers its own request.
func answer_pause(accepted: bool) -> void:
	if is_host:
		if _client_peer_id > 1 and _pending_requester == _client_peer_id:
			_finish_pause_request(accepted)
	elif _pending_requester == 1 and connected:
		_pending_requester = 0
		answer_pause_rpc.rpc_id(1, accepted)


func _finish_pause_request(accepted: bool) -> void:
	_pending_requester = 0
	if accepted:
		_match_paused = _pending_pause_state
	pause_state_changed.emit(_match_paused)
	if connected and multiplayer.get_peers().size() > 0:
		set_pause_state.rpc(_match_paused)


func _on_pause_answer(sender: int, accepted: bool) -> void:
	if is_host and sender > 1 and sender == _client_peer_id and _pending_requester == 1:
		_finish_pause_request(accepted)


func _on_host_pause_request(sender: int, requested_state: bool) -> void:
	if not is_host and sender == 1:
		_pending_pause_state = requested_state
		_pending_requester = 1
		pause_request_received.emit(1, requested_state)


func _wire_multiplayer() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_peer_connected(peer_id: int) -> void:
	if not is_host or peer_id <= 1 or multiplayer.get_peers().size() > MAX_CLIENTS:
		return
	_client_peer_id = peer_id
	_configure_peer_timeout(peer_id)
	last_input_seq.erase(peer_id)
	last_action_seq.erase(peer_id)
	_remote_frame = _neutral_input()
	status_changed.emit("Đã kết nối người chơi · phòng đầy")
	lobby_ready.emit()


func _on_connected_to_server() -> void:
	_connection_deadline = 0.0
	connected = true
	_configure_peer_timeout(1)
	status_changed.emit("Đã vào phòng LAN · đang tải trận")
	lobby_ready.emit()


func _configure_peer_timeout(peer_id: int) -> void:
	if peer != null:
		var enet_peer := peer.get_peer(peer_id)
		if enet_peer != null:
			enet_peer.set_timeout(32, 10000, 10000)


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host or peer_id != _client_peer_id:
		return
	last_input_seq.erase(peer_id)
	last_action_seq.erase(peer_id)
	_client_peer_id = 0
	_remote_frame.clear()
	pause_state_changed.emit(false)
	status_changed.emit("Đối phương đã ngắt kết nối")
	connection_lost.emit()


func _on_connection_failed() -> void:
	_fail_connection("Kết nối thất bại; kiểm tra IP, port và firewall")


func _on_server_disconnected() -> void:
	_fail_connection("Đã mất kết nối tới máy host")


@rpc("any_peer", "call_remote", "reliable")
func request_pause_rpc(requested_state: bool) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == _client_peer_id and sender > 1:
		_pending_pause_state = requested_state
		_pending_requester = sender
		pause_request_received.emit(sender, requested_state)


@rpc("authority", "call_remote", "reliable")
func receive_pause_request(requested_state: bool) -> void:
	_on_host_pause_request(multiplayer.get_remote_sender_id(), requested_state)


@rpc("any_peer", "call_remote", "reliable")
func answer_pause_rpc(accepted: bool) -> void:
	_on_pause_answer(multiplayer.get_remote_sender_id(), accepted)


@rpc("authority", "call_remote", "reliable")
func set_pause_state(is_paused: bool) -> void:
	_match_paused = is_paused
	pause_state_changed.emit(is_paused)


func _fail_connection(message: String) -> void:
	_connection_deadline = 0.0
	connected = false
	status_changed.emit(message)
	_close_peer()
	pause_state_changed.emit(false)
	connection_lost.emit()


func _close_peer() -> void:
	if peer != null:
		peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	peer = null
	is_host = false


func send_input(payload: Dictionary) -> void:
	if not connected:
		return
	if is_host:
		input_received.emit(1, payload)
		return
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	_movement_sequence += 1
	var movement := {
		"move_x": clampf(float(payload.get("move_x", 0.0)), -1.0, 1.0),
		"move_y": clampf(float(payload.get("move_y", 0.0)), -1.0, 1.0),
		"camera_yaw": float(payload.get("camera_yaw", 0.0)),
		"guard": bool(payload.get("guard", false)),
		"seq": _movement_sequence
	}
	submit_input.rpc_id(1, movement)

	var actions := {
		"horn": bool(payload.get("horn", false)),
		"dash": bool(payload.get("dash", false)),
		"guard_pressed": bool(payload.get("guard_pressed", false)),
		"hook": bool(payload.get("hook", false)),
		"release": bool(payload.get("release", false))
	}
	if actions.values().has(true):
		_action_sequence += 1
		submit_action.rpc_id(1, _action_sequence, actions)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(payload: Dictionary) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != _client_peer_id or sender <= 1:
		return
	var sequence := int(payload.get("seq", -1))
	if not _accept_sequence(last_input_seq, sender, sequence):
		return
	last_input_seq[sender] = sequence

	_remote_frame["move_x"] = clampf(float(payload.get("move_x", 0.0)), -1.0, 1.0)
	_remote_frame["move_y"] = clampf(float(payload.get("move_y", 0.0)), -1.0, 1.0)
	_remote_frame["camera_yaw"] = float(payload.get("camera_yaw", 0.0))
	_remote_frame["guard"] = bool(payload.get("guard", false))
	_remote_frame["seq"] = sequence


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_action(sequence: int, actions: Dictionary) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != _client_peer_id or sender <= 1:
		return
	if not _accept_sequence(last_action_seq, sender, sequence):
		return
	last_action_seq[sender] = sequence

	for action_name in ["horn", "dash", "guard_pressed", "hook", "release"]:
		_remote_frame[action_name] = (
			bool(_remote_frame.get(action_name, false)) or bool(actions.get(action_name, false))
		)
	_remote_frame["seq"] = sequence


func _accept_sequence(sequences: Dictionary, sender: int, sequence: int) -> bool:
	return sequence >= 0 and sequence > int(sequences.get(sender, -1))


func _neutral_input() -> Dictionary:
	return {
		"move_x": 0.0,
		"move_y": 0.0,
		"camera_yaw": 0.0,
		"horn": false,
		"dash": false,
		"guard": false,
		"guard_pressed": false,
		"hook": false,
		"release": false,
		"seq": 0
	}


func send_snapshot(payload: Dictionary) -> void:
	if not is_host:
		return
	snapshot_received.emit(payload)
	if connected and multiplayer.get_peers().size() > 0:
		receive_snapshot.rpc(payload)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_snapshot(payload: Dictionary) -> void:
	snapshot_received.emit(payload)


func send_event(payload: Dictionary) -> void:
	if not is_host:
		return
	event_received.emit(payload)
	if connected and multiplayer.get_peers().size() > 0:
		receive_event.rpc(payload)


@rpc("authority", "call_remote", "reliable", 0)
func receive_event(payload: Dictionary) -> void:
	event_received.emit(payload)
