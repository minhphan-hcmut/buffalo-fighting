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
	root.size = Vector2i(1280, 720)
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.set_process(false)
	var rig := arena.get_node("CameraRig")
	rig.set_process(false)
	rig.set_physics_process(false)
	var camera := root.get_camera_3d()
	camera.reparent(arena)
	camera.global_position = Vector3(0, 3, 8)
	camera.look_at(Vector3(0, 2, 0))
	arena.player.position = Vector3(-0.1, 0, 0)
	arena.opponent.position = Vector3(0.1, 0, 0)
	var first := arena.player.get_node("CombatFeedback") as BuffaloFeedback
	var second := arena.opponent.get_node("CombatFeedback") as BuffaloFeedback
	first.set_process(false)
	second.set_process(false)
	arena.combat_event.emit(&"WHIFF_START", 1, 2, 0.0)
	check(is_equal_approx(first.label.scale.x, GameBalance.get_number("combat_label_start_scale")), "label starts at small pop scale")
	first._process(GameBalance.get_number("combat_label_pop_s") * GameBalance.get_number("combat_label_peak_at"))
	check(is_equal_approx(first.label.scale.x, GameBalance.get_number("combat_label_peak_scale")), "label pop reaches its overshoot")
	first._process(GameBalance.get_number("combat_label_pop_s") * (1.0 - GameBalance.get_number("combat_label_peak_at")))
	check(is_equal_approx(first.label.scale.x, 1.0) and first.label.global_position.y > GameBalance.get_number("combat_label_height"), "pop settles while label drifts up")
	arena.combat_event.emit(&"COUNTER_HIT", 2, 1, 0.0)
	first._process(0.0)
	check(first.label.global_position.y > first._label_position().y, "older overlapping label is displaced upward")
	check(is_equal_approx(first.label.modulate.a, GameBalance.get_number("combat_label_older_alpha")) and second.label.modulate.a == 1.0, "only older overlapping label dims")
	var old_rect := first._label_rect(camera, first.label.global_position)
	var new_rect := second._label_rect(camera, second.label.global_position)
	check(old_rect.end.y <= new_rect.position.y - GameBalance.get_number("combat_label_gap_px") + 0.01, "projected label bounds are separated by configured pixel gap")
	check(second.label_importance > first.label_importance and second.label.modulate.is_equal_approx(BuffaloFeedback.GLOW_HORN), "counter word is larger and matches yellow horn glow")
	second._process(GameBalance.get_number("combat_label_pop_s"))
	check(is_equal_approx(second.label.scale.x, GameBalance.get_number("combat_label_important_scale")), "important label settles larger than ordinary label")
	arena.combat_event.emit(&"PARRY_SUCCESS", 1, 2, 0.0)
	second._process(0.0)
	check(first.label.modulate.is_equal_approx(BuffaloFeedback.GLOW_PARRY) and second.label.modulate.a < first.label.modulate.a, "newer event reverses label priority and parry is green")
	arena.opponent.position.x = 12.0
	second._process(0.0)
	check(second.label.global_position.is_equal_approx(second._label_position()) and second.label.modulate.a == 1.0, "separate projected words restore normal position and opacity")
	arena.paused = true
	var remaining := first.label_time
	var position_before := first.label.global_position
	var scale_before := first.label.scale
	first._process(0.2)
	check(first.label_time == remaining and first.label.global_position == position_before and first.label.scale == scale_before, "pause freezes label timing, position and scale")
	arena.paused = false
	first._process(GameBalance.get_number("combat_label_s") * (1.0 - GameBalance.get_number("combat_label_fade_fraction") * 0.5))
	check(is_equal_approx(first.label.modulate.a, 0.5) and is_equal_approx(first.label.outline_modulate.a, 0.5), "word and outline both fade in final thirty percent")
	first._process(GameBalance.get_number("combat_label_s"))
	check(not first.label.visible, "word disappears when its lifetime ends")
	camera.clear_current(false)
	arena.combat_event.emit(&"WHIFF_START", 1, 2, 0.0)
	first._process(0.0)
	check(first.label.visible and first.label.modulate == Color.WHITE, "feedback works without an active camera")
	camera.make_current()
	var vfx := arena.vfx as MatchVFX
	vfx.set_process(false)
	for child in vfx.bursts.get_children():
		child.free()
	vfx.on_combat_event(&"HORN_HIT", 1, 2)
	var flash := vfx.bursts.get_child(0) as CPUParticles3D
	var dust := vfx.bursts.get_child(1) as CPUParticles3D
	var dust_material := dust.mesh.material as StandardMaterial3D
	var dust_texture := dust_material.albedo_texture as GradientTexture2D
	check(flash.mesh == vfx.particle_mesh and flash.scale_amount_curve == null and flash.color_initial_ramp == null, "flash keeps original mesh and animation")
	check(dust.mesh != flash.mesh and dust_texture.width == GameBalance.get_int("vfx_dust_texture_size"), "dust uses its own high-resolution radial sprite")
	check(dust_texture.fill == GradientTexture2D.FILL_RADIAL and dust_texture.gradient.sample(1.0).a == 0.0 and dust_texture.gradient.sample(0.0).a == 1.0 and dust_texture.gradient.sample(0.5).a < 0.5, "dust texture has transparent edges and soft radial falloff")
	check(dust.scale_amount_curve.sample(0.0) < dust.scale_amount_curve.sample(1.0) and dust.scale_amount_min < dust.scale_amount_max, "dust puffs vary in size and grow over lifetime")
	check(dust.color_initial_ramp.get_color(0).a < dust.color_initial_ramp.get_color(1).a and dust.color_initial_ramp.get_color(1).a < 1.0 and dust.color_ramp.get_color(1).a == 0.0, "dust varies in opacity and fades away")
	check(dust.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX and dust.emission_box_extents.y < dust.global_position.y, "dust spawns above ground in a shallow layer")
	var snapshot := arena.get_snapshot()
	first._process(0.01)
	vfx._process(0.01)
	check(snapshot == arena.get_snapshot(), "label and dust presentation do not change simulation")
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	overlay.show()
	SessionState.last_match_level = &"L01"
	SessionState.last_winner = 1
	SessionState.level_id = &"L02"
	overlay._show_result("win-L01")
	check(overlay.result_actions.get_child_count() == 3 and overlay.result_actions.get_child(0).text.begins_with("TRẬN TIẾP THEO") and overlay.result_actions.get_child(0).has_focus(), "L01 win puts next-round button first and focuses it")
	check(overlay.result_actions.get_child(1).text == "CHƠI LẠI TRẬN NÀY", "retry remains available second after a win")
	SessionState.last_match_level = &"L02"
	SessionState.level_id = &"L03"
	overlay._show_result("win-L02")
	check(overlay.result_actions.get_child(0).text.ends_with("CHUNG KẾT") and overlay.result_actions.get_child(0).has_focus(), "semifinal win focuses next-round final action")
	SessionState.last_match_level = &"L02"
	SessionState.last_winner = 2
	overlay._show_result("loss-L02")
	check(overlay.result_actions.get_child_count() == 2 and overlay.result_actions.get_child(0).text == "CHƠI LẠI TRẬN NÀY" and overlay.result_actions.get_child(0).has_focus(), "loss keeps retry first and focused")
	SessionState.last_match_level = &"L03"
	SessionState.last_winner = 1
	overlay._show_result("final-L03")
	var ceremony := overlay.find_child("Ceremony", true, false) as CeremonyView
	check(ceremony != null and not overlay.result_panel.visible, "final win still shows closing ceremony first")
	if ceremony != null:
		ceremony.finish()
	check(overlay.result_actions.get_child_count() == 2 and overlay.result_actions.get_child(0).text == "CHƠI LẠI TRẬN NÀY" and overlay.result_actions.get_child(0).has_focus(), "final win keeps existing retry focus after closing ceremony")
	overlay.queue_free()
	arena.queue_free()
	await process_frame
	await process_frame
	print("POLISH BATCH 1 FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
