extends SceneTree
## Windowed captures of the real shared effects, at the tutorial's contact time.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.theme = load("res://assets/ui/festival_theme.tres")
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	SessionState.auto_pause_enabled = false
	var howto := HowToPlay.new()
	root.add_child(howto)
	howto.select_tab(1)
	var demo := howto.demo
	demo.set_physics_process(false)
	await create_timer(1.0).timeout
	for id in [&"dash", &"parry", &"clash"]:
		demo.select_move(id)
		demo.sample_time(GameBalance.get_number("demo_hit_at_s"))
		for actor in [demo.red, demo.blue]:
			for step in 30:
				actor.visual.update_pose(1.0 / 60.0)
		demo._align_contact()
		demo.vfx.reset()
		demo.fired_events.clear()
		demo._timeline_events(GameBalance.get_number("demo_hit_at_s"))
		demo.vfx._process(0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "res://production/qa/evidence/howto-vfx-%s.png" % id
		if root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) != OK:
			quit(1)
			return
		print("CAPTURE ", id, " bursts=", demo.vfx.bursts.get_child_count())
	howto.queue_free()
	await process_frame
	quit(0)
