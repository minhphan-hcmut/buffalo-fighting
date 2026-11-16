extends SceneTree
## Windowed settings evidence; four local captures, never the player's settings files.


func _initialize() -> void:
	call_deferred("run")


func shot(label: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var path := "res://production/qa/evidence/settings-%s.png" % label
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
	SessionState.load_settings("user://settings_window_qa.cfg")
	SessionState.auto_pause_enabled = false
	GraphicsQuality.reset("user://settings_window_graphics_qa.cfg")
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_settings()
	await shot("audio-720")
	menu.menu_settings_layer.tabs[3].pressed.emit()
	await shot("graphics-720")
	menu.menu_settings_layer.tabs[4].pressed.emit()
	await shot("effects-720")
	menu.menu_settings_layer.close()
	menu.free()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	SessionState.begin_free_play(&"L01")
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.start_playing()
	arena.request_pause_from_menu()
	arena.hud.show_settings()
	arena.hud.settings_screen.select_tab(1)
	await shot("pause-1080")
	arena.hud.settings_screen.close()
	arena.resume_from_menu()
	arena.free()
	for path in ["user://settings_window_qa.cfg", "user://settings_window_graphics_qa.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0)
