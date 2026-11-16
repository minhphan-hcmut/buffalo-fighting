extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://production/qa/evidence/%s.png" % name
	if root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) != OK:
		failures += 1


func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	create_timer(45.0).timeout.connect(func(): push_error("Solo capture timed out"); quit(1))
	root.theme = load("res://assets/ui/festival_theme.tres")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	SessionState.auto_pause_enabled = false
	SessionState.replay_enabled = false
	SessionState.begin_free_play(&"L01")
	change_scene_to_file("res://scenes/arena.tscn")
	await scene_changed
	var arena := current_scene as MatchController
	var overlay := Control.new()
	overlay.name = "SoloSessionOverlay"
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	await create_timer(0.6).timeout
	arena.start_playing()
	arena.player.position = Vector3(-3.0, 0.0, 0.0)
	arena.opponent.position = Vector3(5.0, 0.0, -2.0)
	arena.opponent.spirit = 0.0
	arena.hitstop_ticks = GameBalance.get_int("hitstop_hit_ticks")
	arena._check_match_end()
	while arena.outro.lead != MatchOutro.Lead.LEAD or arena.opponent.position.x < GameBalance.get_number("arena_rx") - 3.0:
		await physics_frame
		if arena.result_ready:
			failures += 1
			break
	var rig := arena.get_node("CameraRig")
	var lens: Camera3D = rig.camera
	var observer := Camera3D.new()
	observer.fov = lens.fov
	arena.add_child(observer)
	var center: Vector3 = arena.opponent.global_position.lerp(arena.outro.handler.global_position, 0.5) + Vector3.UP
	# QA observation angle makes the rope, handler and actual gate gap legible.
	observer.global_position = center + Vector3(-5.0, 4.0, 8.0)
	observer.look_at(center)
	observer.current = true
	await process_frame
	await capture("handlers-outro")
	observer.queue_free()
	lens.current = true
	while not arena.result_ready:
		await physics_frame
	await create_timer(GameBalance.get_number("result_winner_blend_s") + 0.4).timeout
	for actor in [arena.player, arena.opponent]:
		if not is_zero_approx(actor.visual.speed):
			failures += 1
	if arena.opponent.visible or not overlay.result_panel.visible or arena.hitstop_ticks != 0:
		failures += 1
	await capture("result-settled-solo")
	print("SOLO WINDOW: ", failures, " failures; speeds=", arena.player.visual.speed, "/", arena.opponent.visual.speed, "; outro=", arena.outro.time)
	quit(0 if failures == 0 else 1)
