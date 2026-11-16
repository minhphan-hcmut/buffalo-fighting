extends SceneTree
## Real ENet/windows through lan_netem_proxy.py; three complete bouts, rematches,
## client disconnect/rejoin, then a host process exit. Test input uses InputFrame.

var host_side := false
var role := "client"
var profile := "clean"
var arena: MatchController
var manager: Node
var failures := 0
var bouts: Array = []
var event_counts: Dictionary = {}
var final_snapshot: Dictionary = {}
var max_step := 0.0
var previous_remote := Vector3.ZERO
var tracked_actor := 0
var last_horn := -1
var last_dash := -1
var pause_requested := false
var resume_at := 0
var saw_pause := false
var now_seconds := 0.0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	host_side = OS.get_cmdline_user_args().has("--host")
	role = "host" if host_side else "client"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
	create_timer(420.0).timeout.connect(func(): save_report(); push_error("Netem window harness timed out"); quit(1))
	root.theme = load("res://assets/ui/festival_theme.tres")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_position(Vector2i(0, 0) if host_side else Vector2i(560, 260))
		DisplayServer.window_set_title("LAN NETEM %s %s" % [profile, role])
	Engine.max_fps = 60
	SessionState.auto_pause_enabled = false
	SessionState.replay_enabled = false
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	manager = root.get_node("NetworkManager")
	manager.event_received.connect(_event)
	process_frame.connect(track_remote)
	check((manager.host(7777) if host_side else manager.join("127.0.0.1", 7778)) == OK, "connection starts through UDP relay")
	await manager.lobby_ready
	await load_arena()
	for bout in 3:
		await play_bout(bout)
		if bout == 0 and profile == "typical":
			await capture_winner()
		await rematch()
	# The fourth bout tests a client leaving while PLAYING.
	await playing()
	if host_side:
		while not arena.lan.peer_left:
			await process_frame
		await process_frame
		check(arena.end_reason == &"CONNECTION_LOST" and arena.result_ready, "client disconnect ends the host match honestly")
		check(arena.hud.pause_overlay.visible and arena.hud.rematch_button.disabled, "disconnect UI permits menu, prevents rematch")
		manager.leave()
		check(manager.host(7777) == OK, "host can reopen for a rejoin")
	else:
		await create_timer(0.6).timeout
		arena.hud._return_to_menu()
		await scene_changed
		check(not manager.connected and current_scene.scene_file_path == "res://scenes/main_menu.tscn", "client disconnect returns to an interactive menu")
		await create_timer(manager.CONNECTION_TIMEOUT_SECONDS + 2.0).timeout
		check(manager.join("127.0.0.1", 7778) == OK, "client rejoins through the same relay")
	await manager.lobby_ready
	await load_arena()
	await playing()
	check(manager.connected and arena.phase == &"PLAYING", "rejoined session reaches PLAYING")
	if host_side:
		await create_timer(1.0).timeout
		save_report()
		# Actual host process shutdown, not a synthesized connection_lost signal.
		manager.leave()
		quit(0 if failures == 0 else 1)
	else:
		while manager.connected:
			await process_frame
		await process_frame
		check(arena.end_reason == &"CONNECTION_LOST" and arena.result_ready, "host process exit unlocks the client result")
		check(arena.hud.pause_overlay.visible and arena.hud.rematch_button.disabled, "host exit leaves usable result UI")
		arena.hud._return_to_menu()
		await scene_changed
		check(current_scene.scene_file_path == "res://scenes/main_menu.tscn", "client can leave the lost-host result")
		save_report()
		quit(0 if failures == 0 else 1)


func load_arena() -> void:
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	change_scene_to_file("res://scenes/arena.tscn")
	await scene_changed
	arena = current_scene as MatchController
	if not manager.pause_request_received.is_connected(_accept_pause):
		manager.pause_request_received.connect(_accept_pause)


func playing() -> void:
	while arena.phase != &"PLAYING":
		await physics_frame


func _accept_pause(_peer: int, _requested: bool) -> void:
	# The real consent panel is already built by MatchController's signal handler.
	for button in arena.hud.pause_actions.get_children():
		if button is Button and button.text == "CHẤP NHẬN":
			button.pressed.emit()
			return
	check(false, "pause consent button exists")


func _event(payload: Dictionary) -> void:
	if payload.get("type") == "RESULT":
		final_snapshot = payload.snapshot.duplicate(true)
	elif payload.get("type") == "COMBAT":
		var event: String = payload.event
		event_counts[event] = int(event_counts.get(event, 0)) + 1


func frame_for(actor: Buffalo, other: Buffalo, seconds: float) -> InputFrame:
	var frame := InputFrame.new(actor.slot)
	var toward := other.global_position - actor.global_position
	frame.camera_yaw = atan2(-toward.x, -toward.z)
	frame.seq = arena.tick
	if toward.length() > GameBalance.get_number("clash_distance"):
		frame.move = Vector2(0.0, -1.0)
	if not arena.active_clash.is_empty():
		frame.move = Vector2(0.0, -1.0)
		if actor.slot == 1:
			frame.horn_pressed = not actor.clash_hooked and actor.stamina >= GameBalance.get_number("horn_cost") and float(arena.active_clash.time) >= GameBalance.get_number("lock_hook_startup_s")
		return frame
	var bucket := int(seconds / 1.6)
	if actor.slot == 2:
		if seconds < 24.0 and bucket != last_horn:
			frame.horn_pressed = true
			last_horn = bucket
	elif seconds < 12.0:
		frame.horn_pressed = other.state in [Buffalo.State.HORN_STARTUP, Buffalo.State.HORN_ACTIVE]
	elif seconds < 24.0:
		frame.parry_pressed = other.state == Buffalo.State.HORN_STARTUP and other.state_time >= GameBalance.get_number("horn_startup_s") - GameBalance.get_number("parry_active_s") * 0.5
	else:
		if bucket != last_horn:
			frame.horn_pressed = true
			last_horn = bucket
		var dash_bucket := int(seconds / 5.0)
		if dash_bucket != last_dash:
			frame.dash_pressed = true
			frame.horn_pressed = false
			last_dash = dash_bucket
	return frame


func play_bout(bout: int) -> void:
	await playing()
	arena.set_physics_process(false)
	event_counts.clear()
	final_snapshot.clear()
	max_step = 0.0
	last_horn = -1
	last_dash = -1
	pause_requested = false
	saw_pause = false
	resume_at = 0
	while not arena.finished:
		await physics_frame
		var delta := 1.0 / Engine.physics_ticks_per_second
		now_seconds = GameBalance.get_number("match_duration_s") - arena.remaining_time
		if host_side and now_seconds >= 8.0 and not pause_requested:
			pause_requested = true
			arena.request_pause_from_menu()
		if arena.paused:
			saw_pause = true
			if host_side:
				if resume_at == 0:
					resume_at = Time.get_ticks_msec() + 600
				elif Time.get_ticks_msec() >= resume_at:
					arena.resume_from_menu()
					resume_at = 9223372036854775807
			continue
		if host_side:
			arena.simulate_tick(delta, frame_for(arena.player, arena.opponent, now_seconds))
			var snapshot := arena.get_snapshot()
			if arena.finished:
				arena.lan.send_result(snapshot)
			else:
				arena.lan.broadcast_snapshot(delta, snapshot)
		else:
			arena.lan.upload_input(delta, frame_for(arena.opponent, arena.player, now_seconds))
	check(saw_pause and not arena.paused, "bout %d pauses and resumes on both peers" % (bout + 1))
	for event in ["CLASH_START", "PARRY_SUCCESS", "DASH_START", "CLASH_HOOK"]:
		check(event_counts.get(event, 0) > 0, "bout %d includes actual %s" % [bout + 1, event])
	check(not final_snapshot.is_empty(), "reliable final snapshot exists")
	var summary := {"bout": bout + 1, "snapshot": canonical(final_snapshot), "events": event_counts.duplicate(), "max_remote_step_m": max_step, "pause": saw_pause, "errors": failures}
	bouts.append(summary)
	print("BOUT ", JSON.stringify(summary))
	arena.set_physics_process(true)
	while not arena.result_ready:
		await process_frame
	await process_frame
	check(arena.hud.pause_overlay.visible and arena.hud.rematch_button != null, "result UI does not stick")


func canonical(snapshot: Dictionary) -> Dictionary:
	var players: Array = []
	for item: Dictionary in snapshot.get("players", []):
		var position: Vector2 = item.position
		players.append({"slot": item.slot, "position": [position.x, position.y], "spirit": item.spirit, "stamina": item.stamina})
	return {"winner": snapshot.get("winner_slot"), "reason": snapshot.get("end_reason"), "players": players}


func track_remote() -> void:
	if host_side or not is_instance_valid(arena) or not arena.is_inside_tree() or arena.phase != &"PLAYING":
		tracked_actor = 0
		return
	var actor := arena.player
	if tracked_actor == actor.get_instance_id():
		max_step = maxf(max_step, previous_remote.distance_to(actor.global_position))
	previous_remote = actor.global_position
	tracked_actor = actor.get_instance_id()


func rematch() -> void:
	var old_id := arena.get_instance_id()
	if manager.pause_request_received.is_connected(_accept_pause):
		manager.pause_request_received.disconnect(_accept_pause)
	arena.hud.rematch_button.pressed.emit()
	while current_scene == null or current_scene.get_instance_id() == old_id:
		await process_frame
	arena = current_scene as MatchController
	manager.pause_request_received.connect(_accept_pause)
	check(arena != null and not arena.finished, "rematch reloads a fresh match")


func capture_winner() -> void:
	await create_timer(GameBalance.get_number("result_winner_blend_s") + 0.3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := "res://production/qa/evidence/lan-result-winner-%s.png" % role
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "winner screenshot")
	check(arena.get_node("CameraRig").winner_time >= 0.0, "LAN uses the Solo winner camera")


func save_report() -> void:
	var file := FileAccess.open("res://.scratch/orca/howto-lan-perf-2026-11-16/lan-%s-%s.json" % [profile, role], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"profile": profile, "role": role, "bouts": bouts, "failures": failures}, "\t"))
