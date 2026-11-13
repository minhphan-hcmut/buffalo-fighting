extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	root.size = Vector2i(1280, 720)
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L02"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	var hud = arena.hud
	hud.set_process(false)
	var punch := GameBalance.get_number("ui_countdown_punch_s")
	var punch_scale := GameBalance.get_number("ui_countdown_punch_scale")
	var hold := GameBalance.get_number("ui_fight_banner_s")
	var fade := GameBalance.get_number("ui_fight_banner_fade_s")
	var hint := GameBalance.get_number("ui_controls_hint_s")
	var hint_fade := GameBalance.get_number("ui_controls_hint_fade_s")
	for sample in [[2.4, "3"], [1.2, "2"], [0.3, "1"]]:
		arena.countdown_time = sample[0]
		hud._process(0.0)
		check(hud.center_label.text == sample[1], "countdown rounds %.1f up to %s" % sample)
		check(hud.center_label.scale.is_equal_approx(Vector2.ONE * punch_scale), "each new digit starts a punch")
		hud._process(punch * 0.5)
		check(hud.center_label.scale.x > 1.0 and hud.center_label.scale.x < punch_scale, "punch interpolates between start and rest")
		hud._process(punch)
		check(hud.center_label.scale == Vector2.ONE, "punch settles without overshoot")
	check(hud.center_label.get_theme_font_size("font_size") == GameBalance.get_int("ui_countdown_font_size"), "countdown uses configured large font")
	check(hud.center_label.get_theme_color("font_color") == Color("#F2E6CF"), "countdown uses cream text")
	check(hud.center_label.pivot_offset == hud.center_label.size * 0.5, "punch pivots around label center")
	check(hud.tutorial_label.visible and hud.tutorial_label.text.contains("G Gạt sừng"), "controls are available before PLAYING outside L01")
	arena.phase = &"PLAYING"
	hud._process(0.0)
	check(hud.center_label.text == "VÀO TRẬN!", "COUNTDOWN to PLAYING starts fight banner")
	check(hud.center_label.get_theme_color("font_color") == Color("#E8BC65") and is_equal_approx(hud.center_label.scale.x, punch_scale), "fight banner is gold and punches")
	check(hud.tutorial_label.visible, "L02 controls start visible")
	arena.paused = true
	hud._process(hint + hold + fade)
	check(hud.center_label.text == "VÀO TRẬN!" and hud.center_label.modulate.a == 1.0, "pause holds banner")
	check(hud.tutorial_label.visible and hud.tutorial_label.modulate.a == 1.0, "pause does not consume controls hint")
	arena.paused = false
	hud._process(hold)
	check(hud.center_label.text == "VÀO TRẬN!" and hud.center_label.modulate.a == 1.0, "banner stays opaque for configured hold")
	hud._process(fade * 0.5)
	check(hud.center_label.modulate.a > 0.0 and hud.center_label.modulate.a < 1.0, "banner fades after hold")
	hud._process(fade)
	check(hud.center_label.text == "" and hud.center_label.scale == Vector2.ONE and hud.center_label.modulate.a == 1.0, "expired banner clears and resets presentation")
	hud._process(hint - hint_fade * 0.5 - hud.controls_hint_time)
	check(hud.tutorial_label.visible and hud.tutorial_label.modulate.a > 0.0 and hud.tutorial_label.modulate.a < 1.0, "controls fade near the end of their hint time")
	hud._process(hint_fade)
	check(not hud.tutorial_label.visible, "L02 controls hide after configured PLAYING time")
	check(hud.tutorial_label.text.contains("G Gạt sừng"), "hidden controls retain their guide text")
	arena.phase = &"RESULT"
	hud._process(0.0)
	check(hud.tutorial_label.visible and hud.tutorial_label.modulate.a == 1.0 and hud.tutorial_label.text == "Kết quả đã khóa · bấm Esc để thả chuột", "RESULT restores the opaque exit hint")
	arena.mode = &"LAN"
	arena.phase = &"COUNTDOWN"
	arena.countdown_time = 1.2
	hud._process(0.0)
	check(hud.center_label.text == "2", "LAN countdown reads replicated phase and time")
	arena.phase = &"PLAYING"
	hud._process(0.0)
	check(hud.center_label.text == "VÀO TRẬN!" and hud.tutorial_label.visible, "LAN phase transition starts banner and controls")
	hud._process(hint + hint_fade)
	check(not hud.tutorial_label.visible, "LAN controls also expire")
	arena.mode = &"SOLO"
	arena.level_id = &"L01"
	hud._process(hint + hint_fade)
	check(hud.tutorial_label.visible and hud.tutorial_label.modulate.a == 1.0 and hud.tutorial_current == 1, "L01 retains its visible context tutorial")
	arena.free()
	print("HUD COUNTDOWN FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
