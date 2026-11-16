extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func run() -> void:
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.begin_solo()
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.hud.set_process(false)
	arena.start_playing()
	var rig := arena.get_node("CameraRig")
	rig.set_process(false)
	rig.set_physics_process(false)
	var camera := root.get_camera_3d()
	camera.reparent(arena)
	var first := arena.player.get_node("CombatFeedback") as BuffaloFeedback
	var second := arena.opponent.get_node("CombatFeedback") as BuffaloFeedback
	first.set_process(false)
	second.set_process(false)
	check(first.label.font_size == roundi(GameBalance.get_number("combat_label_font_size") * GameBalance.get_number("combat_callout_size_scale")), "callout uses configured smaller type")
	var visible_samples := 0
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		for distance in [3.0, 5.0, 8.0]:
			camera.position = Vector3(0, 3, distance)
			camera.look_at(Vector3(0, 1.4, -1.2))
			arena.player.position = Vector3(-0.4, 0, 0)
			arena.opponent.position = Vector3(0.4, 0, -2.5)
			for event: StringName in [&"PARRY_SUCCESS", &"COUNTER_HIT", &"WHIFF_START"]:
				second.label_time = 0.0
				second.label.hide()
				first._on_event(event, 1, 2, 0.0)
				first._process(GameBalance.get_number("combat_label_pop_s"))
				var expected := ControlsDiagram.PAPER
				if event == &"PARRY_SUCCESS":
					expected = BuffaloFeedback.GLOW_PARRY.lerp(expected, GameBalance.get_number("combat_callout_parry_paper_mix"))
				elif event == &"COUNTER_HIT":
					expected = ControlsDiagram.GOLD
				check(first.label.modulate.is_equal_approx(expected), "callout colour matches its role")
				if first.label.visible:
					visible_samples += 1
					var rect := first._label_rect(camera, first.label.global_position)
					check(root.get_visible_rect().grow(1.0).encloses(rect), "callout fits the viewport")
					check(not rect.grow(GameBalance.get_number("combat_label_gap_px") * 0.5).intersects(first._head_rect(camera, arena.opponent)), "callout clears the opponent's head/horns")
				second._on_event(&"COUNTER_HIT", 2, 1, 0.0)
				first._process(0.0)
				second._process(0.0)
				for feedback: BuffaloFeedback in [first, second]:
					if feedback.label.visible:
						var other := arena.opponent if feedback == first else arena.player
						check(not feedback._label_rect(camera, feedback.label.global_position).intersects(feedback._head_rect(camera, other)), "simultaneous callouts keep head clearance after stacking")
	check(visible_samples > 0, "normal camera distances retain visible callouts")
	arena.player.state = Buffalo.State.PARRY_ACTIVE
	check(first.glow_color().is_equal_approx(BuffaloFeedback.GLOW_PARRY), "horn glow remains unchanged")
	arena.player.state = Buffalo.State.NORMAL
	var hud = arena.hud
	arena.player.position = Vector3.ZERO
	arena.opponent.position = Vector3(0, 0, -7)
	hud._process(0.0)
	check(hud.tutorial_current == 1 and hud.tutorial_label.visible, "L01 starts with its first context hint")
	var fade := GameBalance.get_number("tutorial_hint_fade_s")
	hud._process(GameBalance.get_number("tutorial_hint_s") - fade * 0.5)
	check(hud.tutorial_label.modulate.a > 0.0 and hud.tutorial_label.modulate.a < 1.0, "context hint fades near expiry")
	hud._process(GameBalance.get_number("ui_controls_hint_s"))
	check(not hud.tutorial_label.visible, "L01 guide stays hidden after its first hints expire")
	var writes: int = hud.label_writes
	for frame in 60:
		hud._process(1.0 / 60.0)
	check(not hud.tutorial_label.visible and hud.label_writes == writes, "expired guide does not reappear or rewrite text")
	hud._tutorial_event(&"DASH_HIT", 2, 1, 0.0)
	hud._process(0.0)
	check(hud.tutorial_label.visible and hud.tutorial_current == 4 and hud.tutorial_label.modulate.a == 1.0, "only a new hint restores the bar")
	arena.player.stamina = 0.0
	hud._process(0.0)
	check(hud.player_stamina.custom_minimum_size.y >= GameBalance.get_number("ui_stamina_bar_height"), "stamina bar retains its readable minimum height")
	check(hud.stamina_labels[0].text == "SỨC THẤP" and hud.stamina_labels[0].get_theme_font_size("font_size") >= GameBalance.get_int("ui_stamina_warning_size"), "low stamina keeps a readable textual warning")
	arena.free()
	for frame in 2:
		await physics_frame
	print("HUD CALLOUT: %d failed; %d visible samples" % [failures, visible_samples])
	quit(1 if failures else 0)
