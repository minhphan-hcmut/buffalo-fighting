class_name MatchController
extends Node3D
## Authoritative local/host match simulation and shared InputFrame entry point.
## Owns the match phase, timer, pause and win rules; delegates the rest:
## ArenaBuilder/ArenaBounds (arena), CombatResolver (hits), ClashSystem (horn lock),
## MatchInput (local input) and MatchNetwork (LAN).

signal match_started(level_id: StringName)
signal combat_event(event_name: StringName, source_slot: int, target_slot: int, value: float)
signal resource_changed(slot: int, spirit: float, stamina: float)
signal match_ended(winner_slot: int, end_reason: StringName)
signal snapshot_changed(snapshot: Dictionary)

const BUFFALO := preload("res://scenes/buffalo.tscn")
const AI_CONTROL := preload("res://scripts/ai/ai_controller.gd")
const HUD := preload("res://scripts/ui/hud.gd")

var level_id: StringName = &"L01"
var mode: StringName = &"SOLO"
var phase: StringName = &"READY"
var end_reason: StringName = &"NONE"
var winner_slot := 0
var remaining_time := 0.0
var countdown_time := 0.0
var tick := 0
var finished := false
var paused := false
var player: Buffalo
var opponent: Buffalo
var ai
var hud
var network: Node
var match_seed := 0
var mud_zones: Array[StringName] = []
var local_slot := 1
var combat := CombatResolver.new(self)
var clash := ClashSystem.new(self)
var local_input := MatchInput.new()
## Null outside LAN.
var lan: MatchNetwork
## Live CLASH state, empty when no CLASH is running (see ClashSystem.active).
var active_clash: Dictionary:
	get:
		return clash.active
	set(value):
		clash.active = value


func _ready() -> void:
	mode = SessionState.mode
	level_id = SessionState.level_id
	network = get_node_or_null("/root/NetworkManager")
	if mode == &"LAN" and network == null:
		mode = &"SOLO"
		level_id = &"L01"
	MatchInput.configure()
	var level := _level_config()
	mud_zones.assign(level.get("mud_zones", []))
	ArenaBuilder.build(self, mud_zones)
	var spawn_x := GameBalance.get_number("buffalo_spawn_offset_x", 10.0)
	player = spawn_buffalo(Vector3(-spawn_x, 0.0, 0.0), 1, Color("#B6453B"), "06", "GIÁP ĐÔNG")
	opponent = spawn_buffalo(Vector3(spawn_x, 0.0, 0.0), 2, Color("#33546D"), "17", "GIÁP TÂY")
	player.rotation.y = -PI / 2.0
	opponent.rotation.y = PI / 2.0
	player.camera_yaw = player.rotation.y
	opponent.camera_yaw = opponent.rotation.y
	local_slot = 1 if mode != &"LAN" or network.is_host else 2
	$CameraRig.setup(player if local_slot == 1 else opponent)
	if mode == &"LAN":
		lan = MatchNetwork.new(self, network)
		lan.connect_signals()
	else:
		ai = Node.new()
		ai.set_script(AI_CONTROL)
		ai.actor = opponent
		ai.target = player
		ai.profile = StringName(level.get("ai_profile", "EASY"))
		add_child(ai)
	hud = CanvasLayer.new()
	hud.set_script(HUD)
	hud.controller = self
	add_child(hud)
	match_ended.connect(hud.show_result)
	match_ended.connect(_on_match_ended)
	combat_event.connect(_on_combat_event)
	start_countdown()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if phase == &"RESULT":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if phase != &"PLAYING":
		return
	if mode == &"LAN":
		network.request_pause(not paused)
		hud.show_pause_wait(not paused)
	else:
		_set_paused(not paused)
	get_viewport().set_input_as_handled()


func request_pause_from_menu() -> void:
	if mode == &"LAN":
		network.request_pause(not paused)
		hud.show_pause_wait(not paused)
		return
	_set_paused(true)


func resume_from_menu() -> void:
	if mode == &"LAN":
		network.request_pause(false)
		hud.show_pause_wait(false)
		return
	_set_paused(false)


func _set_paused(is_paused: bool) -> void:
	paused = is_paused
	$CameraRig.gameplay_enabled = not paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(hud):
		if paused:
			hud.show_pause()
		else:
			hud.hide_pause()


func _on_pause_request_received(peer_id: int, requested_state: bool) -> void:
	if is_instance_valid(hud):
		hud.show_pause_confirmation(peer_id, requested_state)


func _on_pause_state_changed(is_paused: bool) -> void:
	_set_paused(is_paused)


func _on_combat_event(event_name: StringName, _source_slot: int, _target_slot: int, _value: float) -> void:
	$CameraRig.trigger_shake(event_name)


func _level_config() -> Dictionary:
	var file := FileAccess.open("res://data/levels.json", FileAccess.READ)
	if file == null:
		return {}
	var levels: Dictionary = JSON.parse_string(file.get_as_text())
	return levels.get(String(level_id), levels["L01"])


func start_countdown() -> void:
	phase = &"COUNTDOWN"
	countdown_time = GameBalance.get_number("countdown_s", 3.0)
	remaining_time = GameBalance.get_number("match_duration_s", 90.0)
	match_seed = Time.get_ticks_msec()
	local_input.arm_release_gates()


func start_playing() -> void:
	if finished:
		return
	phase = &"PLAYING"
	remaining_time = GameBalance.get_number("match_duration_s", 90.0)
	match_started.emit(level_id)


func _physics_process(delta: float) -> void:
	if paused or finished:
		return
	if phase == &"COUNTDOWN":
		local_input.update_release_gates()
		if lan != null and lan.is_client():
			return
		countdown_time -= delta
		if lan != null:
			lan.broadcast_snapshot(delta, get_snapshot())
		if countdown_time <= 0.0:
			start_playing()
		return
	if lan != null and lan.is_client():
		lan.upload_input(delta, _read_player_input())
		return
	if phase != &"PLAYING":
		return
	tick += 1
	clash.tick_cooldown(delta)
	var player_frame := _read_player_input()
	var opponent_frame := _opponent_input(delta)
	player.begin_input(player_frame)
	opponent.begin_input(opponent_frame)
	player.update_facing(delta)
	opponent.update_facing(delta)
	player.update_timers(delta)
	opponent.update_timers(delta)
	player.advance_state(delta)
	opponent.advance_state(delta)
	if clash.is_active():
		clash.process(delta, player_frame, opponent_frame)
	else:
		_simulate_actor(player, player_frame, delta)
		_simulate_actor(opponent, opponent_frame, delta)
		ArenaBounds.constrain(player)
		ArenaBounds.constrain(opponent)
		ArenaBounds.separate(player, opponent)
		combat.resolve_attacks()
	remaining_time = maxf(0.0, remaining_time - delta)
	_emit_resources()
	_check_match_end()
	var snapshot := get_snapshot()
	snapshot_changed.emit(snapshot)
	if lan != null:
		lan.broadcast_snapshot(delta, snapshot)


func _process(delta: float) -> void:
	if lan != null and lan.is_client():
		lan.interpolate(delta)


func _read_player_input() -> InputFrame:
	return local_input.read(local_slot, $CameraRig.yaw, tick)


## Slot 2 input: the AI in Solo, the latest client frame on a LAN host.
func _opponent_input(delta: float) -> InputFrame:
	if is_instance_valid(ai):
		return ai.build_input(delta)
	if lan != null:
		return lan.remote_frame
	return InputFrame.new(2)


func _simulate_actor(actor: Buffalo, frame: InputFrame, delta: float) -> void:
	var camera_forward := Vector3(-sin(frame.camera_yaw), 0.0, -cos(frame.camera_yaw))
	var camera_right := Vector3(cos(frame.camera_yaw), 0.0, -sin(frame.camera_yaw))
	var move_dir := actor.movement_world(frame, camera_forward, camera_right)
	var terrain_factor := 1.0
	if ArenaBounds.in_mud(actor.global_position, mud_zones):
		terrain_factor = GameBalance.get_number("mud_speed_factor", 0.8)
	actor.simulate_movement(delta, move_dir, terrain_factor)


func _check_match_end() -> void:
	if finished:
		return
	if player.spirit <= 0.0 and opponent.spirit <= 0.0:
		_finish_lot()
	elif player.spirit <= 0.0:
		_finish(2, &"FLEE")
	elif opponent.spirit <= 0.0:
		_finish(1, &"FLEE")
	elif remaining_time <= 0.0:
		clash.resolve_timeout()
		if is_equal_approx(player.spirit, opponent.spirit):
			_finish_lot()
		else:
			_finish(1 if player.spirit > opponent.spirit else 2, &"TIME")


func _finish_lot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	_finish(1 if rng.randi_range(0, 1) == 0 else 2, &"LOT")


func _finish(winner: int, reason: StringName) -> void:
	if finished:
		return
	finished = true
	phase = &"RESULT"
	winner_slot = winner
	end_reason = reason
	player.freeze()
	opponent.freeze()
	match_ended.emit(winner_slot, end_reason)


func _on_match_ended(winner: int, reason: StringName) -> void:
	SessionState.last_winner = winner
	SessionState.last_reason = reason
	if mode == &"SOLO" and winner == 1:
		SessionState.advance_after_win()


func _emit_resources() -> void:
	resource_changed.emit(1, player.spirit, player.stamina)
	resource_changed.emit(2, opponent.spirit, opponent.stamina)


func get_snapshot() -> Dictionary:
	return {
		"tick": tick,
		"phase": phase,
		"remaining_ms": int(remaining_time * 1000.0),
		"countdown_ms": int(countdown_time * 1000.0),
		"winner_slot": winner_slot,
		"end_reason": end_reason,
		"players": [
			{"slot": 1, "position": Vector2(player.position.x, player.position.z), "facing": Vector2(player.facing.x, player.facing.z), "spirit": player.spirit, "stamina": player.stamina, "action": player.state_name()},
			{"slot": 2, "position": Vector2(opponent.position.x, opponent.position.z), "facing": Vector2(opponent.facing.x, opponent.facing.z), "spirit": opponent.spirit, "stamina": opponent.stamina, "action": opponent.state_name()}
		]
	}


func spawn_buffalo(at: Vector3, actor_slot: int, color: Color, number: String, faction: String) -> Buffalo:
	var actor := BUFFALO.instantiate() as Buffalo
	actor.slot = actor_slot
	actor.position = at
	add_child(actor)
	ArenaBuilder.add_identifier(actor, color, number, faction)
	return actor
