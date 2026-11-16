extends SceneTree

const EXPECTED := "res://tests/hud_efficiency_expected.json"
var failures := 0
var recorded := {}
var expected := {}
var recording := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func fixture(training: bool = false) -> MatchController:
	SessionState.hud_text_large = false
	if training:
		SessionState.begin_training(&"dummy")
	else:
		SessionState.begin_free_play(&"L03")
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.hud.set_process(false)
	return arena

func snapshot(name: String, hud: CanvasLayer) -> void:
	var state := {}
	for field: String in ["timer_label", "center_label", "announcer_label", "result_label", "clash_title", "clash_time_label", "clash_hook_label", "clash_keys_label", "tutorial_label", "training_counter", "training_popup"]:
		var control: Control = hud.get(field)
		if control != null:
			state[field] = [control.get_parsed_text() if control is RichTextLabel else control.text, control.visible]
	var values: Array = []
	for bar: Range in [hud.player_spirit, hud.player_stamina, hud.opponent_spirit, hud.opponent_stamina, hud.clash_bar]:
		values.append(bar.value)
	state["values"] = values
	state["spirit_labels"] = hud.spirit_labels.map(func(label: Label): return label.text)
	state["stamina_labels"] = hud.stamina_labels.map(func(label: Label): return label.text)
	# Normalize float representations through the same JSON path as the golden data.
	state = JSON.parse_string(JSON.stringify(state))
	recorded[name] = state
	if not recording:
		check(state == expected.get(name), name + " retains every HUD text/value/visibility from before optimization")

func settle() -> void:
	for frame in GameBalance.get_int("vfx_warm_up_settle_frames") + GameBalance.get_int("vfx_warm_up_frames") + 2:
		await process_frame

func run() -> void:
	recording = OS.get_cmdline_user_args().has("--record")
	if not recording:
		expected = DataFile.load_json(EXPECTED)
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	var arena := fixture()
	var hud: CanvasLayer = arena.hud
	hud._process(0.125)
	snapshot("countdown-3", hud)
	arena.countdown_time = 1.2
	hud._process(0.125)
	snapshot("countdown-2", hud)
	arena.start_playing()
	hud._process(0.125)
	snapshot("playing-banner", hud)
	hud.fight_banner_time = 100.0
	hud.controls_hint_time = 100.0
	hud._process(0.0)
	snapshot("playing-stable", hud)
	if not recording:
		var text_writes: int = hud.label_writes
		var range_writes: int = hud.range_writes
		for frame in 180:
			hud._process(1.0 / 60.0)
		check(hud.label_writes == text_writes and hud.range_writes == range_writes, "180 unchanged frames perform zero Label/RichTextLabel text or Range value writes")
	arena.player.spirit = 63.0
	arena.player.stamina = 27.35
	arena.opponent.spirit = 41.5
	arena.opponent.stamina = 10.0
	hud._process(0.0)
	snapshot("playing-resources", hud)
	arena.active_clash = {"a": arena.player, "b": arena.opponent, "time": 1.2, "lock_balance": 23.45}
	arena.player.clash_hooked = true
	hud._process(0.0)
	snapshot("clash-red", hud)
	SessionState.hud_text_large = true
	arena.opponent.clash_hooked = true
	hud._process(0.0)
	snapshot("clash-both-large", hud)
	SessionState.hud_text_large = false
	arena.active_clash = {}
	arena._finish(1, &"TIME")
	arena.outro.time = GameBalance.get_number("result_skip_grace_s") + 0.5
	hud._process(0.5)
	snapshot("result-skip", hud)
	await settle()
	arena.free()
	arena = fixture(true)
	hud = arena.hud
	arena.start_playing()
	hud._process(0.0)
	snapshot("training-start", hud)
	arena.combat_event.emit(&"HORN_HIT", 1, 2, 1.0)
	arena.combat_event.emit(&"PARRY_SUCCESS", 1, 2, 0.0)
	hud._process(0.25)
	snapshot("training-popup", hud)
	hud.training_popup_time = 0.0
	hud._process(0.0)
	snapshot("training-cleared", hud)
	await settle()
	arena.free()
	if recording:
		var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
		file.store_string(JSON.stringify(recorded))
		file.close()
	SessionState.hud_text_large = false
	SessionState.return_to_menu()
	await process_frame
	print("HUD EFFICIENCY FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
