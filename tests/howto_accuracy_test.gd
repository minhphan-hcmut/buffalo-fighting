extends SceneTree

var failures := 0
const HUD := preload("res://scripts/ui/hud.gd")
const BINDINGS := {
	"move_forward": [KEY_W, "W"], "move_left": [KEY_A, "A"],
	"move_back": [KEY_S, "S"], "move_right": [KEY_D, "D"],
	"dash": [KEY_SPACE, "Space"], "parry": [KEY_G, "G"],
	"ui_cancel": [KEY_ESCAPE, "Esc"],
	"horn": [MOUSE_BUTTON_LEFT, "Chuột trái"], "guard": [MOUSE_BUTTON_RIGHT, "Chuột phải"]
}
const COSTS := {
	"horn": "horn_cost", "dash": "dash_cost", "guard": "guard_stamina_per_s",
	"parry": "parry_stamina_cost", "clash": "lock_stamina_per_s", "flank": "horn_cost"
}


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func text_of(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result = node.text + "\n"
	for child in node.get_children():
		result += text_of(child)
	return result


func kinds(vfx: MatchVFX) -> Array:
	return vfx.bursts.get_children().map(func(node: Node): return node.get_meta("kind"))


func run() -> void:
	MatchInput.configure()
	var howto := HowToPlay.new()
	root.add_child(howto)
	howto.select_tab(1)
	var demo := howto.demo
	demo.set_physics_process(false)
	demo.vfx.set_process(false)
	var controls := text_of(howto.pages[2])
	for action in BINDINGS:
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				found = found or event.physical_keycode == BINDINGS[action][0] or event.keycode == BINDINGS[action][0]
			elif event is InputEventMouseButton:
				found = found or event.button_index == BINDINGS[action][0]
		check(found and controls.contains(BINDINGS[action][1]), "Control label matches InputMap: " + action)
	check(controls.contains("F12") and FileAccess.get_file_as_string("res://scripts/ui/screenshot_service.gd").contains("event.keycode == KEY_F12"), "Screenshot label matches global handler")
	check(HUD.CONTROLS.contains("WASD") and HUD.CONTROLS.contains("Space") and HUD.CONTROLS.contains("G Gạt") and HUD.CONTROLS.contains("Esc"), "HUD uses the checked action keys")
	var expected_keys := ["Chuột trái", "Space", "Giữ chuột phải", "G → Chuột trái", "WASD Đẩy tới · Trái Móc · Phải Nhả", "Chuột trái"]
	for index in MoveDemo.MOVES.size():
		var move: Dictionary = MoveDemo.MOVES[index]
		check(move.keys == expected_keys[index] and move.cost == COSTS[move.id], "Move binding and balance key: " + move.name)
		demo.select_move(move.id)
		var expected := "SỨC: %d" % GameBalance.get_int(COSTS[move.id])
		if move.id == &"guard":
			expected += "/giây khi giữ · cần ít nhất %d" % GameBalance.get_int("guard_min_stamina")
		elif move.id == &"parry":
			expected += " gạt + %d húc phản đòn" % GameBalance.get_int("horn_cost")
		elif move.id == &"clash":
			expected += "/giây đẩy · %d mỗi lần móc" % GameBalance.get_int("horn_cost")
		check(demo.cost.text == expected, "Rendered cost: " + move.name)
	for entry in [[0, "Clock", "match_duration_s", "%d giây"], [1, "Stamina", "stamina_max", "SỨC · %d"], [2, "Flank", "flank_damage_multiplier", "Sườn ×%s"], [2, "BackMultiplier", "back_damage_multiplier", "Lưng ×%s"], [2, "Fence", "pinned_spirit_multiplier", "Sát rào ×%s"]]:
		var diagram := howto.pages[0].get_child(entry[0]).get_node("Diagram")
		check(diagram.get_node(entry[1]).text == entry[3] % GameBalance.get_number(entry[2]), "Diagram value: " + entry[2])
	# Changing the source data must change the displayed cost and diagram, too.
	for balance_key in ["horn_cost", "dash_cost", "guard_stamina_per_s", "parry_stamina_cost", "lock_stamina_per_s", "guard_min_stamina"]:
		var old: float = GameBalance.values[balance_key]
		GameBalance.values[balance_key] = old + 7
		for move in MoveDemo.MOVES:
			if move.cost == balance_key or (balance_key == "horn_cost" and move.id in [&"clash", &"parry"]) or (balance_key == "guard_min_stamina" and move.id == &"guard"):
				demo.select_move(move.id)
				check(demo.cost.text.contains(str(int(old + 7))), "Live balance value: " + balance_key)
		GameBalance.values[balance_key] = old
	await vfx_checks(demo)
	howto.queue_free()
	await process_frame
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await physics_frame
	await physics_frame
	print("HOWTO ACCURACY: ", failures, " failures")
	quit(0 if failures == 0 else 1)


func vfx_checks(demo: MoveDemo) -> void:
	SessionState.mode = &"SOLO"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.vfx.set_process(false)
	for frame in GameBalance.get_int("vfx_warm_up_frames") + GameBalance.get_int("vfx_warm_up_settle_frames") + 2:
		await process_frame
	var expected := {&"horn": &"ImpactFlash", &"dash": &"DashBlast", &"guard": &"GuardSpark", &"parry": &"ParrySpark", &"clash": &"ClashSpark", &"flank": &"ImpactDebris"}
	for move in MoveDemo.MOVES:
		demo.select_move(move.id)
		demo.sample_time(GameBalance.get_number("demo_hit_at_s"))
		demo.vfx._process(0.0)
		check(kinds(demo.vfx).has(expected[move.id]), "Timeline effect: " + move.name)
		var count := demo.vfx.bursts.get_child_count()
		demo.sample_time(GameBalance.get_number("demo_hit_at_s"))
		check(demo.vfx.bursts.get_child_count() == count, "Event fires once: " + move.name)
		if move.id == &"clash":
			demo.sample_time(GameBalance.get_number("demo_counter_at_s"))
			check(kinds(demo.vfx).has(&"ClashHook"), "Clash timeline fires hook")
			var sparks_before := kinds(demo.vfx).count(&"ClashSpark")
			demo.vfx._process(GameBalance.get_number("vfx_clash_spark_interval_s"))
			check(kinds(demo.vfx).count(&"ClashSpark") > sparks_before, "Clash timeline keeps periodic sparks")
		demo.set_active(false)
		check(demo.vfx.bursts.get_children().all(func(node: CPUParticles3D): return node.speed_scale == 0.0), "Hidden demo freezes VFX")
		demo.set_active(true)
		demo.set_physics_process(false)
		demo.sample_time(0.0)
		check(demo.vfx.bursts.get_child_count() == 0 and demo.active_clash.is_empty(), "Loop resets effects: " + move.name)
	demo.select_move(&"flank")
	demo.sample_time(GameBalance.get_number("demo_hit_at_s"))
	var flash: CPUParticles3D = demo.vfx.bursts.get_children().filter(func(node: Node): return node.get_meta("kind") == &"ImpactFlash")[0]
	check(is_equal_approx(flash.scale_amount_max, GameBalance.get_number("vfx_flash_size") * GameBalance.get_number("vfx_impact_heavy_scale")), "Flank preview emphasizes bonus with the heavy impact preset")
	for event in [&"HORN_START", &"HORN_HIT", &"DASH_START", &"DASH_HIT", &"GUARD_HIT", &"PARRY_SUCCESS", &"COUNTER_START", &"COUNTER_HIT", &"FLANK_HIT", &"CLASH_START", &"CLASH_HOOK"]:
		demo.vfx.reset()
		arena.vfx.reset()
		demo.vfx.on_combat_event(event, 1, 2)
		arena.combat_event.emit(event, 1, 2, 0.0)
		check(kinds(demo.vfx) == kinds(arena.vfx), "Match signal preserves burst kinds: " + String(event))
		check(demo.vfx.lights.get_child_count() == arena.vfx.lights.get_child_count(), "Match light parity: " + String(event))
	for flash_mode in [0, 1, 2]:
		SessionState.impact_flash = flash_mode
		for preset in [GraphicsQuality.LOW, GraphicsQuality.HIGH]:
			GraphicsQuality.set_preset(preset)
			demo.vfx.reset()
			arena.vfx.reset()
			demo.vfx.on_combat_event(&"DASH_HIT", 1, 2)
			arena.combat_event.emit(&"DASH_HIT", 1, 2, 0.0)
			check(kinds(demo.vfx) == kinds(arena.vfx), "Preset burst parity")
			for index in demo.vfx.bursts.get_child_count():
				var preview: CPUParticles3D = demo.vfx.bursts.get_child(index)
				var match_effect: CPUParticles3D = arena.vfx.bursts.get_child(index)
				check(preview.amount == match_effect.amount and preview.lifetime == match_effect.lifetime and preview.color_ramp.get_color(0) == match_effect.color_ramp.get_color(0), "Preset and comfort values match")
			check(demo.vfx.lights.get_child(0).light_energy == arena.vfx.lights.get_child(0).light_energy, "Comfort light parity")
	SessionState.impact_flash = 0
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	arena.queue_free()
	await process_frame
