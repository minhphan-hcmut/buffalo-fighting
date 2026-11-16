extends SceneTree
## Real ENet pair; --proxy uses the existing relay on 7778 -> 7777.

const REPORT := "res://.scratch/orca/balance-ping-2026-11-16/ping-%s-%s.json"
var failures := 0
var host_side := false
var profile := "clean"
var windowed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	host_side = args.has("--host")
	windowed = args.has("--window")
	var proxy := args.has("--proxy")
	for arg in args:
		if arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
	create_timer(85.0).timeout.connect(func(): push_error("Ping pair timeout"); quit(1))
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.auto_pause_enabled = false
	SessionState.replay_enabled = false
	GraphicsQuality.set_preset(GraphicsQuality.LOW)
	if windowed:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_position(Vector2i.ZERO if host_side else Vector2i(550, 260))
		DisplayServer.window_set_title("LAN PING " + ("HOST" if host_side else "CLIENT"))
	var manager := root.get_node("NetworkManager")
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var solo := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(solo)
	check(solo.hud.ping_label == null, "Solo has no ping label")
	solo.free()
	var role := "host" if host_side else "client"
	var path := REPORT % [profile, role]
	var other_path := REPORT % [profile, "client" if host_side else "host"]
	if host_side:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(other_path))
	var port := 7777 if proxy else 47967
	check((manager.host(port) if host_side else manager.join("127.0.0.1", 7778 if proxy else port)) == OK, "ENet connection starts")
	await manager.lobby_ready
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	change_scene_to_file("res://scenes/arena.tscn")
	await scene_changed
	var arena := current_scene as MatchController
	# Headless idles 6.9 ms even with max_fps=0; poll faster for transport calibration.
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	print("PING CALIBRATION cap=", Engine.max_fps, " low_processor=", OS.low_processor_usage_mode)
	if windowed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	check(arena.hud.ping_label != null, "LAN has one ping label")
	# ENet starts its RTT average at 500 ms; let native samples replace that prior.
	await create_timer(25.0).timeout
	var samples: Array[int] = []
	var raw_samples: Array[int] = []
	var enet_samples: Array[float] = []
	for index in (30 if proxy else 8):
		await create_timer(1.0).timeout
		check(manager.ping_ms >= 0 and manager.connected, "live peer has an RTT sample")
		samples.append(manager.ping_ms)
		raw_samples.append(manager.last_rtt_ms)
		enet_samples.append(manager.peer.get_peer(manager._client_peer_id if host_side else 1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	var expected := {"clean": 0.0, "typical": 120.0, "bad": 300.0}
	var mean: float = samples.reduce(func(total: float, value: int): return total + value, 0.0) / samples.size()
	check(absf(mean - expected[profile]) <= 20.0, "smoothed mean RTT tracks two-way relay delay within 20 ms: %.2f" % mean)
	check(arena.hud.ping_label.text == "Ping %d ms" % manager.ping_ms, "HUD displays measured RTT")
	var tint: Color = arena.hud.TIMER_WARNING if manager.ping_ms > GameBalance.get_int("lan_ping_warning_ms") else SettingsControls.MUTED
	check(arena.hud.ping_label.get_theme_color("font_color") == tint, "warning tint follows presentation threshold")
	var writes: int = arena.hud.label_writes
	for index in 60:
		manager.ping_changed.emit(manager.ping_ms)
	check(arena.hud.label_writes == writes, "unchanged ping does not rewrite HUD text")
	var last_ping: int = manager.ping_ms
	manager.ping_reply(-1)
	check(manager.ping_ms == last_ping and not manager._is_ping_peer(manager.multiplayer.get_unique_id()), "unsolicited and local pong cannot change RTT")
	var threshold := GameBalance.get_int("lan_ping_warning_ms")
	arena.hud._update_ping(threshold)
	check(arena.hud.ping_label.get_theme_color("font_color") == SettingsControls.MUTED, "threshold itself stays muted")
	arena.hud._update_ping(threshold + 1)
	check(arena.hud.ping_label.get_theme_color("font_color") == arena.hud.TIMER_WARNING, "above threshold uses warning tint")
	arena.hud._update_ping(manager.ping_ms)
	if windowed:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://production/qa/evidence/lan-ping-%s.png" % role)) == OK, "window screenshot saved")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var report := FileAccess.open(path, FileAccess.WRITE)
	report.store_string(JSON.stringify({"role": role, "profile": profile, "windowed": windowed, "expected_rtt_ms": expected[profile], "mean_ms": mean, "samples_ms": samples, "raw_samples_ms": raw_samples, "enet_samples_ms": enet_samples, "fps": Engine.get_frames_per_second(), "max_fps": Engine.max_fps, "low_processor": OS.low_processor_usage_mode, "process_delta_s": root.get_process_delta_time(), "failures": failures}, "\t"))
	report.close()
	while not FileAccess.file_exists(other_path):
		await process_frame
	await create_timer(0.5).timeout
	manager.leave()
	check(manager.ping_ms == -1 and manager.last_rtt_ms == -1 and manager._ping_pending.is_empty(), "leave clears RTT and pending probes")
	check(arena.hud.ping_label.text == "Ping —", "disconnect clears stale HUD number")
	print("PING PAIR ", role, " ", profile, " mean=", mean, " failures=", failures)
	quit(0 if failures == 0 else 1)
