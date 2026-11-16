extends SceneTree
## Run as a host/client pair; --window also captures four images across two actual windows.

const PORT := 47962
var host_side := false
var windowed := false
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func shot(label: String) -> void:
	if not windowed:
		return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://production/qa/evidence/lan-rematch-%s.png" % label)) == OK, "screenshot " + label)


func run() -> void:
	host_side = OS.get_cmdline_user_args().has("--host")
	windowed = OS.get_cmdline_user_args().has("--window")
	create_timer(55.0).timeout.connect(func(): push_error("LAN rematch pair timed out"); quit(1))
	root.theme = load("res://assets/ui/festival_theme.tres")
	if windowed:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_position(Vector2i.ZERO if host_side else Vector2i(600, 300))
		DisplayServer.window_set_title("LAN REMATCH QA · " + ("HOST" if host_side else "CLIENT"))
	Engine.max_fps = 60
	var manager := root.get_node("NetworkManager")
	var result: Error = manager.host(PORT) if host_side else manager.join("127.0.0.1", PORT)
	check(result == OK, "LAN connection starts")
	await manager.lobby_ready
	var peer_id: int = manager.multiplayer.get_unique_id()
	var connection_id: int = manager.peer.get_instance_id()
	# The loopback test shares user://; wait for the client's initial-panel assertion before offering.
	var ready_path := "user://lan_rematch_ready_%d" % (manager._client_peer_id if host_side else peer_id)
	if host_side:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ready_path))
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	change_scene_to_file("res://scenes/arena.tscn")
	await scene_changed
	var arena := current_scene as MatchController
	while arena.phase != &"PLAYING":
		await physics_frame
	if host_side:
		arena.combat_event.emit(&"HORN_HIT", 1, 2, 1.0)
		arena.opponent.spirit = 0.0
	while not arena.result_ready:
		await physics_frame
	await process_frame
	check(arena.hud.stats.counts.hits > 0 if host_side else arena.hud.stats.counts.received > 0, "first match has nonzero local stats")
	check(arena.hud.rematch_button != null and arena.hud.rematch_button.text == "ĐẤU LẠI", "LAN result has a rematch button beside menu")
	if host_side:
		await shot("result-host")
		while not FileAccess.file_exists(ready_path):
			await process_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ready_path))
		arena.hud.rematch_button.pressed.emit()
		check(arena.lan.local_wants_rematch and not arena.lan.remote_wants_rematch and arena.hud.rematch_button.disabled, "one agreement waits for the other player")
	else:
		var ready := FileAccess.open(ready_path, FileAccess.WRITE)
		ready.store_string("ready")
		ready.close()
		while not arena.lan.remote_wants_rematch:
			await process_frame
		check(arena.hud.rematch_note.text == "Đối phương muốn đấu lại" and arena.hud.rematch_button.text == "ĐỒNG Ý", "peer sees rematch offer and Agree")
		await shot("offer-client")
		arena.hud.rematch_button.pressed.emit()
	var old_id := arena.get_instance_id()
	while current_scene == null or current_scene.get_instance_id() == old_id:
		await process_frame
	arena = current_scene as MatchController
	check(arena != null and arena.phase == &"COUNTDOWN" and not arena.finished, "both agreements create a fresh countdown")
	check(manager.match_epoch == 1 and arena.lan.epoch == 1, "rematch advances both peers to the new epoch")
	check(manager.connected and manager.peer.get_instance_id() == connection_id and manager.multiplayer.get_unique_id() == peer_id, "ENet connection and peer identity survive reload")
	check(arena.local_slot == (1 if host_side else 2), "rematch retains the same player slots")
	check(arena.hud.stats.counts.values().all(func(value: int): return value == 0), "rematch resets every stat counter")
	check(arena.player.spirit == GameBalance.get_number("spirit_max") and arena.opponent.spirit == GameBalance.get_number("spirit_max"), "rematch starts with fresh resources")
	while arena.phase != &"PLAYING":
		await physics_frame
	check(arena.phase == &"PLAYING" and not arena.finished, "new match reaches PLAYING on each peer")
	if host_side:
		await shot("playing-host")
		await create_timer(0.8).timeout
		arena.opponent.spirit = 0.0
	while not arena.result_ready:
		await physics_frame
	await process_frame
	if not host_side:
		arena.hud.rematch_button.pressed.emit()
		while manager.connected:
			await process_frame
		check(arena.hud.rematch_button.disabled and arena.hud.rematch_note.text.contains("rời trận"), "decline leaves peer with disconnect message and no rematch action")
		check(arena.winner_slot == 1 and arena.end_reason == &"FLEE", "disconnect preserves the locked result")
		await shot("declined-client")
		arena.hud._return_to_menu()
	else:
		while not arena.lan.remote_wants_rematch:
			await process_frame
		check(arena.hud.rematch_button.text == "ĐỒNG Ý", "client can also request a rematch")
		arena.hud._return_to_menu()
	await scene_changed
	check(not manager.connected and current_scene.scene_file_path == "res://scenes/main_menu.tscn", "both players can decline/leave to menu")
	await create_timer(0.5).timeout
	print("LAN REMATCH ", "HOST" if host_side else "CLIENT", " FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
