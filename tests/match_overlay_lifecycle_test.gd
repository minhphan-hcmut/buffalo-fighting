extends SceneTree
## Breaks caught: freed modal leaves focus locked, shell duplicates on recreation,
## controller Esc bypasses close intent, and reset(false) is mistaken for resume consent.

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func run() -> void:
	SessionState.auto_pause_enabled = false
	SessionState.begin_free_play(&"L01")
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.start_playing()
	var hud = arena.hud
	var hud_root: Control = hud.get_child(0)
	arena.request_pause_from_menu()
	hud.show_settings()
	var opener: Control = hud.settings_screen.opener
	check(hud.has_method("close_settings_if_open") and hud.has_method("return_to_menu"), "HUD exposes explicit settings-close and menu intents")
	if hud.has_method("close_settings_if_open"):
		check(hud.close_settings_if_open() and not hud.close_settings_if_open(), "close intent consumes only an open modal")
		check(arena.paused and opener.has_focus(), "close intent preserves Solo pause and opener focus")
		hud.show_settings()
	escape()
	check(arena.paused and not hud.showing_settings and opener.has_focus(), "controller Esc closes settings without resuming Solo")
	# Free an OPEN modal with the shell: it must restore covered focus modes.
	hud.show_settings()
	hud.pause_overlay.queue_free()
	await process_frame
	await process_frame
	# Baseline cannot recreate a freed shell; guard so RED is an assertion, not an invalid access.
	if is_instance_valid(hud.pause_overlay):
		hud.show_pause()
	else:
		# New presenter exposes shell recreation through the existing façade, not a test-only API.
		if hud.get("pause_view") != null:
			hud.show_pause()
	check(is_instance_valid(hud.pause_overlay), "show_pause recreates a freed overlay")
	if is_instance_valid(hud.pause_overlay):
		check(hud.get_child(0) == hud_root and hud_root.find_children("PauseShade", "", true, false).size() == 1, "recreated shell preserves HUD root and has one backdrop")
		check(not hud.showing_settings and hud.pause_actions.get_child(0).has_focus(), "recreated pause has usable focus and no stale settings state")
		hud.show_settings()
		escape()
		check(arena.paused and hud.pause_panel.visible and hud.settings_screen.opener.has_focus(), "recreated settings closes through real controller input")
		# The same shell serves LAN results, then returns to a clean pause layout.
		arena.mode = &"LAN"
		hud.show_result(1, &"TIME")
		hud._show_lan_result()
		var shell_id: int = hud.pause_overlay.get_instance_id()
		check(hud.pause_overlay.get_node("ResultShade").visible and not hud.pause_overlay.get_node("PauseShade").visible, "LAN result uses only its result backdrop")
		hud.show_pause()
		check(hud.pause_overlay.get_instance_id() == shell_id and hud.pause_overlay.get_node("PauseShade").visible and not hud.pause_overlay.get_node("ResultShade").visible, "result-to-pause resets the SAME shell and shades")
		check(hud.pause_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and hud.pause_panel.anchor_left == 0.5 and not is_instance_valid(hud.stats_panel), "result-to-pause clears stats and restores centered layout")
		hud.show_settings()
		escape()
		check(arena.paused and not hud.showing_settings and hud.settings_screen.opener.has_focus(), "LAN settings Esc retains pause and focus without requesting resume")
	arena.mode = &"SOLO"
	arena.free()
	await process_frame
	check(not is_instance_valid(hud), "open/closed overlay owners are freed with their scene")
	await check_disconnect_classification()
	await check_paused_peer_left()
	SessionState.return_to_menu()
	print("MATCH OVERLAY LIFECYCLE FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func check_paused_peer_left() -> void:
	var manager := root.get_node("NetworkManager")
	check(manager.host(47944) == OK, "paused peer-left fixture binds host port")
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.start_playing()
	manager._client_peer_id = 2
	# A real request goes through controller confirmation and its injected answer action.
	manager._pending_requester = 2
	manager._pending_pause_state = true
	manager.pause_request_received.emit(2, true)
	check(not arena.paused and arena.hud.pause_actions.get_child(0).text == "CHẤP NHẬN", "peer request waits for explicit confirmation")
	arena.hud.pause_actions.get_child(0).pressed.emit()
	check(arena.paused and manager._match_paused, "confirmation action applies requested pause through manager")
	arena.hud.show_settings()
	var opener: Control = arena.hud.settings_screen.opener
	escape()
	check(arena.paused and opener.has_focus() and manager._pending_requester == 0, "LAN controller Esc closes settings without sending a resume request")
	arena.hud.show_settings()
	manager._on_peer_disconnected(2)
	await process_frame
	await process_frame
	check(arena.finished and arena.end_reason == &"CONNECTION_LOST" and arena.lan.peer_left, "peer disconnect while paused locks connection-lost result")
	check(not arena.hud.showing_settings and arena.hud.rematch_button.disabled and arena.hud.rematch_note.text.contains("rời trận"), "peer-left closes settings and disables rematch with explanation")
	check(not arena.hud.rematch_button.has_focus() and root.gui_get_focus_owner().text == "VỀ MENU", "peer-left puts focus on the available menu action")
	arena.free()
	manager.leave()
	await process_frame


func check_disconnect_classification() -> void:
	var manager := root.get_node("NetworkManager")
	var harness = load("res://tests/network_host_harness.gd").new()
	harness.manager = manager
	harness.received_client_action = true
	manager.pause_request_received.connect(harness._on_pause_request)
	manager.pause_state_changed.connect(harness._on_pause_state_changed)
	check(manager.host(47943) == OK, "classification fixture binds isolated host port")
	manager._client_peer_id = 2
	manager._pending_requester = 2
	manager._pending_pause_state = true
	manager.pause_request_received.emit(2, true)
	check(harness.accepted_pause and not harness.accepted_resume, "actual answered pause is recorded without resume")
	# A false state can arrive while still connected: connected alone is not consent.
	manager.pause_state_changed.emit(false)
	check(not harness.accepted_resume, "connected reset(false) without answered request is NOT accepted resume")
	manager._pending_requester = 2
	manager._pending_pause_state = false
	manager.pause_request_received.emit(2, false)
	check(harness.accepted_resume, "actual answered resume request IS accepted resume")
	harness.accepted_resume = false
	manager.leave()
	check(not harness.accepted_resume, "disconnect while paused is NOT accepted resume")
	manager.pause_request_received.disconnect(harness._on_pause_request)
	manager.pause_state_changed.disconnect(harness._on_pause_state_changed)
	harness.free()
	await process_frame
