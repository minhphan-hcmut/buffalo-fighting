extends Node
## Autoload "NetworkManager": the ENet connection for LAN (host/join on port 7777,
## disconnect, pause handshake) and the raw message channels: client inputs,
## host snapshots and reliable events. Match logic lives in MatchNetwork, not here.

signal status_changed(message: String)
signal lobby_ready
signal input_received(peer_id: int, payload: Dictionary)
signal snapshot_received(payload: Dictionary)
signal event_received(payload: Dictionary)
signal connection_lost
signal pause_request_received(peer_id: int, requested_state: bool)
signal pause_state_changed(is_paused: bool)
signal ping_changed(milliseconds: int)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1
const ENET_CHANNEL_COUNT := 3
const CONNECTION_TIMEOUT_SECONDS := 10.0
const CLIENT_SLOT := 2

var peer: ENetMultiplayerPeer
var is_host := false
var connected := false
var match_epoch := 0
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
var ping_ms := -1
var last_rtt_ms := -1
var _ping_average := -1.0
var _ping_pending: Dictionary = {}
var _ping_due_ms := 0


func _ready() -> void:
	_wire_multiplayer()


func _process(_delta: float) -> void:
	if _connection_deadline > 0.0 and Time.get_ticks_msec() >= _connection_deadline:
		_connection_deadline = 0.0
		if not connected and not is_host:
			_fail_connection("Hết thời gian chờ kết nối (10 giây)")
	var now := Time.get_ticks_msec()
	if connected and now >= _ping_due_ms:
		_probe_ping(now)


func _probe_ping(now: int) -> void:
	_ping_due_ms = now + int(GameBalance.get_number("lan_ping_interval_s") * 1000.0)
	var remote := _client_peer_id if is_host else 1
	if peer == null or not multiplayer.get_peers().has(remote):
		return
	var timeout_ms := int(GameBalance.get_number("lan_ping_timeout_s") * 1000.0)
	for stamp: int in _ping_pending.keys():
		if now - stamp > timeout_ms:
			_ping_pending.erase(stamp)
	_ping_pending[now] = true
	ping_probe.rpc_id(remote, now)


func _is_ping_peer(sender: int) -> bool:
	return connected and sender > 0 and sender == (_client_peer_id if is_host else 1)


@rpc("any_peer", "call_remote", "unreliable", 2)
func ping_probe(stamp: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _is_ping_peer(sender) and stamp >= 0:
		ping_reply.rpc_id(sender, stamp)


@rpc("any_peer", "call_remote", "unreliable", 2)
func ping_reply(stamp: int) -> void:
	if not _is_ping_peer(multiplayer.get_remote_sender_id()) or not _ping_pending.has(stamp):
		return
	_ping_pending.erase(stamp)
	var elapsed := Time.get_ticks_msec() - stamp
	if elapsed > GameBalance.get_number("lan_ping_timeout_s") * 1000.0:
		return
	last_rtt_ms = elapsed
	_ping_average = float(elapsed) if _ping_average < 0.0 else lerpf(_ping_average, elapsed, GameBalance.get_number("lan_ping_smoothing_alpha"))
	var displayed := roundi(_ping_average)
	if displayed != ping_ms:
		ping_ms = displayed
		ping_changed.emit(ping_ms)


func _reset_ping() -> void:
	_ping_due_ms = 0
	_ping_pending.clear()
	_ping_average = -1.0
	last_rtt_ms = -1
	if ping_ms != -1:
		ping_ms = -1
		ping_changed.emit(ping_ms)


func _physics_process(_delta: float) -> void:
	if not is_host or _client_peer_id == 0 or _remote_frame.is_empty():
		return
	input_received.emit(CLIENT_SLOT, _remote_frame.duplicate())
	for action_name in ["horn", "dash", "parry", "guard_pressed", "hook", "release"]:
		_remote_frame[action_name] = false


func host(port: int = DEFAULT_PORT) -> Error:
	leave()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS, ENET_CHANNEL_COUNT)
	if error != OK:
		peer = null
		status_changed.emit(Language.t("Không thể mở phòng: %s") % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	connected = true
	_wire_multiplayer()
	var address := local_ipv4()
	if address.is_empty():
		status_changed.emit(Language.t("Đã tạo phòng · cổng %d · chờ người chơi") % port)
	else:
		status_changed.emit(Language.t("Đã tạo phòng · máy kia nhập %s (cổng %d) · chờ người chơi") % [address, port])
	return OK


## First private IPv4 of this machine (192.168.x, 10.x, 172.16–31.x), or "" when none.
## Shown to the host so the other player knows what to type.
static func local_ipv4() -> String:
	for address in IP.get_local_addresses():
		var parts := address.split(".")
		if parts.size() != 4:
			continue
		var a := int(parts[0])
		var b := int(parts[1])
		if a == 192 and b == 168 or a == 10 or a == 172 and b >= 16 and b <= 31:
			return address
	return ""


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		status_changed.emit("Hãy nhập địa chỉ IPv4 của máy tạo phòng")
		return ERR_INVALID_PARAMETER
	leave()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(clean_address, port, ENET_CHANNEL_COUNT)
	if error != OK:
		peer = null
		status_changed.emit(Language.t("Không thể bắt đầu kết nối: %s") % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	connected = false
	_connection_deadline = Time.get_ticks_msec() + int(CONNECTION_TIMEOUT_SECONDS * 1000.0)
	_wire_multiplayer()
	status_changed.emit(Language.t("Đang kết nối tới %s:%d (tối đa 10 giây)") % [clean_address, port])
	return OK


func leave() -> void:
	_reset_ping()
	_connection_deadline = 0.0
	if peer != null:
		peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	peer = null
	connected = false
	match_epoch = 0
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
	_reset_ping()
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
	_fail_connection("Đã mất kết nối tới máy tạo phòng")


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
	_reset_ping()
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
	payload = payload.duplicate()
	payload["match_epoch"] = match_epoch
	if is_host:
		input_received.emit(1, payload)
		return
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	_movement_sequence += 1
	var movement := {
		"match_epoch": match_epoch,
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
		"parry": bool(payload.get("parry", false)),
		"guard_pressed": bool(payload.get("guard_pressed", false)),
		"hook": bool(payload.get("hook", false)),
		"release": bool(payload.get("release", false))
	}
	if actions.values().has(true):
		_action_sequence += 1
		submit_action.rpc_id(1, _action_sequence, actions, match_epoch)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(payload: Dictionary) -> void:
	if not is_host or not same_match(payload):
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
func submit_action(sequence: int, actions: Dictionary, epoch: int = 0) -> void:
	if not is_host or epoch != match_epoch:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != _client_peer_id or sender <= 1:
		return
	if not _accept_sequence(last_action_seq, sender, sequence):
		return
	last_action_seq[sender] = sequence

	for action_name in ["horn", "dash", "parry", "guard_pressed", "hook", "release"]:
		_remote_frame[action_name] = (
			bool(_remote_frame.get(action_name, false)) or bool(actions.get(action_name, false))
		)
	_remote_frame["seq"] = sequence


func _accept_sequence(sequences: Dictionary, sender: int, sequence: int) -> bool:
	return sequence >= 0 and sequence > int(sequences.get(sender, -1))


func _neutral_input() -> Dictionary:
	return {
		"match_epoch": match_epoch,
		"move_x": 0.0,
		"move_y": 0.0,
		"camera_yaw": 0.0,
		"horn": false,
		"dash": false,
		"parry": false,
		"guard": false,
		"guard_pressed": false,
		"hook": false,
		"release": false,
		"seq": 0
	}


func send_snapshot(payload: Dictionary) -> void:
	if not is_host:
		return
	payload = payload.duplicate()
	payload["match_epoch"] = match_epoch
	snapshot_received.emit(payload)
	if connected and multiplayer.get_peers().size() > 0:
		receive_snapshot.rpc(payload)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_snapshot(payload: Dictionary) -> void:
	snapshot_received.emit(payload)


func send_event(payload: Dictionary) -> void:
	if not is_host:
		return
	payload = payload.duplicate()
	payload["match_epoch"] = match_epoch
	event_received.emit(payload)
	if connected and multiplayer.get_peers().size() > 0:
		receive_event.rpc(payload)


@rpc("authority", "call_remote", "reliable", 0)
func receive_event(payload: Dictionary) -> void:
	event_received.emit(payload)


func same_match(payload: Dictionary) -> bool:
	var epoch: Variant = payload.get("match_epoch", 0)
	return epoch is int and epoch == match_epoch


## Client-to-host requests share the reliable event channel; only the connected peer may ask.
func request_rematch() -> void:
	if connected and not is_host:
		submit_rematch.rpc_id(1, match_epoch)


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_rematch(epoch: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host and epoch == match_epoch and sender > 1 and sender == _client_peer_id:
		event_received.emit({"type": "REMATCH_WANT", "match_epoch": epoch})


## Keep ENet and the monotonic input sequences; clear only state belonging to the old match.
func begin_rematch(epoch: int) -> void:
	match_epoch = epoch
	_remote_frame = _neutral_input()
	_match_paused = false
	_pending_requester = 0
