extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	var main_menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(main_menu)
	await process_frame
	main_menu._show_settings()
	check(main_menu.menu_settings_layer.visible, "main-menu settings panel opens")
	main_menu.free()
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	check(arena.player != null and arena.opponent != null, "arena spawns two buffalo")
	check(arena.player.spirit == 100.0 and arena.player.stamina == 100.0, "SPIRIT/STAMINA initialized")
	check(arena.phase == &"COUNTDOWN", "match starts in countdown")
	arena.start_playing()
	check(arena.phase == &"PLAYING", "countdown can enter playing")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	arena._input(escape)
	check(arena.paused and arena.hud.pause_overlay.visible, "PvE pause opens pause panel")
	arena._input(escape)
	check(not arena.paused and not arena.hud.pause_overlay.visible, "PvE pause resumes match")
	arena.hud.show_settings()
	check(arena.hud.pause_overlay.visible, "settings panel opens from pause")
	var frame := InputFrame.new(1)
	frame.camera_yaw = 0.0
	frame.horn_pressed = true
	arena.player.begin_input(frame)
	check(arena.player.state == Buffalo.State.HORN_STARTUP, "HORN starts startup")
	check(arena.player.stamina == 80.0, "HORN costs stamina")
	arena.player.advance_state(0.12)
	check(arena.player.state == Buffalo.State.HORN_ACTIVE, "HORN startup becomes active")
	check(arena.get_snapshot().has("players"), "MatchSnapshot contract exists")
	arena.free()
	print("GDD SMOKE FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
