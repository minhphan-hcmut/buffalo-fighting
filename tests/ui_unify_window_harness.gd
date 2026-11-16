extends SceneTree
## Local window captures of the completed views, without player settings writes.


func _initialize() -> void:
	call_deferred("run")


func shot(label: String, delay := 0.8) -> void:
	await create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var path := "res://production/qa/evidence/ui14-%s.png" % label
	if root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) != OK:
		quit(1)
	print("SCREENSHOT ", path)


func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.load_settings("user://ui14_window_settings.cfg")
	SessionState.auto_pause_enabled = false
	GraphicsQuality.reset("user://ui14_window_graphics.cfg")
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	var stage := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "menu"
	if stage == "menu":
		await shot("menu")
	elif stage == "howto":
		menu._show_how_to_play()
		await shot("howto")
	elif stage == "training":
		menu._show_training()
		await shot("training")
	menu.free()
	if stage == "result":
		SessionState.begin_free_play(&"L01")
		var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
		root.add_child(arena)
		current_scene = arena
		arena.start_playing()
		arena._finish(1, &"TIME")
		arena.outro.time = GameBalance.get_number("result_skip_grace_s")
		var confirm := InputEventKey.new()
		confirm.keycode = KEY_ENTER
		confirm.pressed = true
		arena.outro.skip(confirm)
		arena.result_ready = true
		var overlay := Control.new()
		overlay.set_script(load("res://scripts/ui/main_menu.gd"))
		overlay.set_meta("session_overlay", true)
		root.add_child(overlay)
		await create_timer(2.0).timeout
		await shot("result")
		overlay.free()
		arena.free()
	if stage == "hud":
		SessionState.begin_solo()
		SessionState.level_id = &"L01"
		var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
		root.add_child(arena)
		current_scene = arena
		arena.start_playing()
		arena.set_physics_process(false)
		arena.player.position = Vector3(0, 0, 1.5)
		arena.opponent.position = Vector3(0, 0, -1.5)
		arena.player.stamina = 8.0
		arena.hud.previous_phase = &"PLAYING"
		arena.hud.fight_banner_time = 100.0
		arena.hud.controls_hint_time = 100.0
		arena.hud.tutorial_seen.assign([1, 2, 3, 4, 5, 6])
		await create_timer(1.0).timeout
		arena.combat_event.emit(&"PARRY_SUCCESS", 1, 2, 0.0)
		await shot("hud-callout", 0.08)
		arena.free()
	await process_frame
	quit(0)
