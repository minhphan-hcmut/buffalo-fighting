extends SceneTree
## Countdowns and the fight call must clear the top strips even at maximum pop.

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
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.auto_pause_enabled = false
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for large in [false, true]:
			SessionState.hud_text_large = large
			SessionState.begin_free_play(&"L03")
			var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
			root.add_child(arena)
			arena.set_physics_process(false)
			arena.hud.set_process(false)
			for frame in 5:
				await process_frame
			for text in ["3", "2", "1", "VÀO TRẬN!"]:
				arena.phase = &"COUNTDOWN" if text != "VÀO TRẬN!" else &"PLAYING"
				arena.countdown_time = float(text) if text != "VÀO TRẬN!" else 0.0
				arena.hud.previous_phase = &"COUNTDOWN"
				arena.hud.center_label.text = ""
				arena.hud._process(0.0)
				await process_frame
				var label: Label = arena.hud.center_label
				label.scale = Vector2.ONE * GameBalance.get_number("ui_banner_pop_scale")
				label.pivot_offset = label.size * 0.5
				var rect := label.get_global_rect().grow(GameBalance.get_number("ui_banner_outline_size") + GameBalance.get_number("ui_banner_shadow_offset_y"))
				var context := "%s / %s / %s" % [resolution, "Lớn" if large else "Thường", text]
				check(not rect.intersects(arena.hud.top_bar.get_global_rect()), "banner clears names and bars at max pop: " + context)
				check(not rect.intersects(arena.hud.timer_label.get_global_rect()), "banner clears timer at max pop: " + context)
				check(root.get_visible_rect().encloses(rect), "banner including outline/shadow fits: " + context)
			arena.free()
			await process_frame
	SessionState.hud_text_large = false
	SessionState.return_to_menu()
	print("BANNER LAYOUT FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
