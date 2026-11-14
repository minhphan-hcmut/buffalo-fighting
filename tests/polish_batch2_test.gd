extends SceneTree

const SETTINGS_PATH := "user://polish_batch2_test_settings.cfg"

class AudioSpy extends FestivalAudio:
	var cues: Array[String] = []

	func play_sfx(cue: String) -> AudioStreamPlayer:
		cues.append(cue)
		return null

	func play_music(_cue: String, _looped := false) -> void:
		pass

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func labels(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label or node is Button else ""
	if node is RichTextLabel:
		result = node.get_parsed_text() + "\n"
	for child in node.get_children():
		result += labels(child)
	return result


func run() -> void:
	root.theme = load("res://assets/ui/festival_theme.tres")
	var real_path := ProjectSettings.globalize_path("user://settings.cfg")
	var real_before := FileAccess.get_file_as_bytes(real_path) if FileAccess.file_exists(real_path) else PackedByteArray()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SessionState.load_settings(SETTINGS_PATH)
	check(SessionState.camera_shake_enabled and not SessionState.fullscreen_enabled and is_equal_approx(SessionState.mouse_sensitivity, GameBalance.get_number("mouse_sensitivity")), "missing settings file uses defaults")
	var audio := root.get_node("GameAudio") as FestivalAudio
	for bus in [&"Master", &"Music", &"SFX"]:
		check(is_equal_approx(AudioServer.get_bus_volume_linear(FestivalAudio.ensure_bus(bus)), 1.0), "%s defaults to 100%%" % bus)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_settings()
	for i in 3:
		await process_frame
	var actions: VBoxContainer = menu.menu_settings_actions
	var master := actions.get_child(0).get_child(1) as HSlider
	var music := actions.get_child(1).get_child(1) as HSlider
	var sfx := actions.get_child(2).get_child(1) as HSlider
	var sensitivity := actions.get_child(3).get_child(1) as HSlider
	var sensitivity_value := actions.get_child(3).find_child("Value", true, false) as Label
	check(sensitivity_value.text == "5" and is_equal_approx(sensitivity.ratio, 0.5), "default sensitivity displays 5 at the exact slider midpoint")
	sensitivity.grab_focus()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await process_frame
	check(is_equal_approx(sensitivity.ratio, 0.51), "Right arrow adjusts sensitivity by one slider step")
	right.pressed = false
	Input.parse_input_event(right)
	sensitivity.ratio = 0.0
	check(sensitivity_value.text == "1" and is_equal_approx(SessionState.mouse_sensitivity, GameBalance.get_number("ui_settings_sensitivity_min")), "scale 1 saves the minimum real sensitivity")
	sensitivity.ratio = 1.0
	check(sensitivity_value.text == "10" and is_equal_approx(SessionState.mouse_sensitivity, GameBalance.get_number("ui_settings_sensitivity_max")), "scale 10 saves the maximum real sensitivity")
	sensitivity.ratio = 0.25
	check(sensitivity_value.text == "3" and is_equal_approx(SessionState.mouse_sensitivity, 0.09), "lower half maps linearly between the minimum and default")
	master.value = 63
	music.value = 42
	sfx.value = 81
	sensitivity.ratio = 0.75
	(actions.get_child(5) as CheckButton).button_pressed = false
	check(labels(actions.get_child(0)).contains("63%") and sensitivity_value.text == "7.5" and is_equal_approx(SessionState.mouse_sensitivity, 0.325), "volume keeps its percentage while sensitivity uses the 1–10 scale")
	var config := ConfigFile.new()
	check(config.load(SETTINGS_PATH) == OK and is_equal_approx(config.get_value("audio", "Master"), 0.63) and is_equal_approx(config.get_value("audio", "Music"), 0.42) and is_equal_approx(config.get_value("audio", "SFX"), 0.81), "each slider change saves the three bus volumes to the injected path")
	check(is_equal_approx(config.get_value("settings", "mouse_sensitivity"), 0.325), "settings file keeps real sensitivity for compatibility")
	SessionState.mouse_sensitivity = 0.24
	SettingsControls.set_fullscreen(true)
	SessionState.mouse_sensitivity = -1.0
	SessionState.camera_shake_enabled = true
	SessionState.fullscreen_enabled = false
	AudioServer.set_bus_volume_linear(FestivalAudio.ensure_bus(&"Master"), 1.0)
	SessionState.load_settings(SETTINGS_PATH)
	check(not SessionState.camera_shake_enabled and SessionState.fullscreen_enabled and is_equal_approx(SessionState.mouse_sensitivity, 0.24) and is_equal_approx(AudioServer.get_bus_volume_linear(FestivalAudio.ensure_bus(&"Master")), 0.63), "reload restores toggles, mouse sensitivity and volume")
	var reopened := VBoxContainer.new()
	var callback_values: Array[float] = []
	SettingsControls.populate(reopened, func(value: float): callback_values.append(value))
	root.add_child(reopened)
	var restored_slider := reopened.get_child(3).get_child(1) as HSlider
	check(is_equal_approx(restored_slider.ratio, 0.63) and reopened.get_child(3).find_child("Value", true, false).text == "6.3" and is_equal_approx(SessionState.mouse_sensitivity, 0.24), "old real sensitivity restores the slider and label without rewriting the saved value")
	restored_slider.ratio = 0.75
	check(callback_values.size() == 1 and is_equal_approx(callback_values[0], 0.325), "shared pause callback receives real sensitivity rather than the display scale")
	reopened.free()
	SettingsControls.set_fullscreen(false)
	var invalid := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	invalid.store_string("[settings\nthis is damaged")
	invalid.close()
	Engine.print_error_messages = false
	SessionState.load_settings(SETTINGS_PATH)
	Engine.print_error_messages = true
	check(SessionState.camera_shake_enabled and not SessionState.fullscreen_enabled and is_equal_approx(SessionState.mouse_sensitivity, GameBalance.get_number("mouse_sensitivity")) and is_equal_approx(AudioServer.get_bus_volume_linear(0), 1.0), "damaged ConfigFile falls back to defaults")
	config.clear()
	config.set_value("audio", "Master", "invalid")
	config.set_value("audio", "Music", -1.0)
	config.set_value("audio", "SFX", 2.0)
	config.set_value("settings", "fullscreen", "invalid")
	config.set_value("settings", "camera_shake", 0)
	config.set_value("settings", "mouse_sensitivity", 50.0)
	config.save(SETTINGS_PATH)
	SessionState.load_settings(SETTINGS_PATH)
	check(SessionState.camera_shake_enabled and not SessionState.fullscreen_enabled and is_equal_approx(SessionState.mouse_sensitivity, GameBalance.get_number("mouse_sensitivity")) and is_equal_approx(AudioServer.get_bus_volume_linear(0), 1.0), "wrong types and out-of-range settings use defaults")
	var focus: Control = master
	var reached: Array[Control] = []
	for i in 7:
		reached.append(focus)
		focus = focus.find_next_valid_focus()
	check(reached.has(music) and reached.has(sfx) and reached.has(sensitivity) and reached.has(actions.get_child(4)) and reached.has(actions.get_child(5)) and reached.has(actions.get_child(-1)), "keyboard focus reaches all settings controls and Back")
	var settings_panel := menu.menu_settings_layer.get_child(1) as PanelContainer
	check(root.get_visible_rect().encloses(settings_panel.get_global_rect()) and settings_panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 1.0, "settings panel fits the viewport and stays centered")
	check(settings_panel.size.y < 620.0, "settings panel shrinks to its content")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(menu.menu_layout.visible and not menu.menu_settings_layer.visible, "Esc closes settings")
	var howto_button := menu.menu_layout.get_node("HowToPlayButton") as Button
	var settings_button := menu.menu_layout.get_node("SettingsButton") as Button
	check(howto_button.get_index() + 1 == settings_button.get_index(), "How to Play sits between LAN and Settings")
	check(howto_button.pressed.get_connections().size() == 2 and settings_button.pressed.get_connections().size() == 2, "new menu buttons keep their action and global click sound")
	for toggle in [actions.get_child(4), actions.get_child(5)]:
		check(toggle.pressed.get_connections().is_empty(), "settings toggle does not trigger a menu click sound")
	check(master.value_changed.get_connections().size() == 2, "slider only updates its setting and value label")
	howto_button.pressed.emit()
	for i in 3:
		await process_frame
	var howto := menu.get_node("HowToPlay") as HowToPlay
	var text := labels(howto).to_lower()
	for banned in ["máu", "hp", "hòa", "đo ván", "lủi sới"]:
		check(not text.contains(banned), "How to Play excludes forbidden wording: " + banned)
	check(text.contains("%d giây" % GameBalance.get_int("match_duration_s")) and text.contains("bốc thăm") and text.contains("khí thế không hồi"), "How to Play follows current time, tie-break and resource rules")
	var howto_panel := howto.get_child(1) as PanelContainer
	check(root.get_visible_rect().encloses(howto_panel.get_global_rect()), "How to Play fits 1280 x 720")
	check(howto.tabs.size() == 3, "How to Play delegates to its three-tab control")
	check(not menu.menu_layout.visible and menu.find_child("MenuBackdrop", true, false) != null, "How to Play opens above the 3D menu background")
	Input.parse_input_event(escape)
	await process_frame
	# queue_free() completes after the frame that emits process_frame.
	await process_frame
	check(not is_instance_valid(howto) and menu.menu_layout.visible and howto_button.has_focus(), "Esc frees How to Play and restores focus")
	howto_button.pressed.emit()
	var reopened_howto := menu.get_node("HowToPlay") as HowToPlay
	reopened_howto.find_child("Back", true, false).pressed.emit()
	check(not reopened_howto.visible and menu.menu_layout.visible, "How to Play reopens and Back closes it")
	menu.free()

	for cue in audio.settings.cues:
		var tuning: Dictionary = audio.settings.cues[cue]
		for i in 4:
			var voice := audio.play_sfx(cue)
			check(voice != null, "cue resolves an existing audio asset: " + cue)
			if voice == null:
				break
			var pitch := float(tuning.get("pitch", 1.0))
			var jitter := float(tuning.get("pitch_jitter", 0.0))
			check(is_equal_approx(voice.volume_db, float(tuning.db)) and voice.pitch_scale >= pitch - jitter - 0.00001 and voice.pitch_scale <= pitch + jitter + 0.00001, "cue applies configured dB and pitch range: " + cue)
			voice.stop()
	var tuned: Dictionary = audio.settings.cues
	audio.settings.cues = {}
	var fallback := audio.play_sfx("buffalo_horn_hit")
	check(is_equal_approx(fallback.volume_db, float(audio.settings.sfx_db)) and is_equal_approx(fallback.pitch_scale, 1.0), "unconfigured cues retain original volume and pitch")
	fallback.stop()
	audio.settings.cues = tuned
	var announcer := audio.play_sfx("announcer_intro_vi")
	audio._process(0.0)
	check(is_equal_approx(audio.music.volume_db, float(audio.settings.music_db) + float(audio.settings.announcer_music_duck_db)), "announcer ducks music without changing the saved Music bus")
	announcer.stop()
	audio._process(0.0)
	check(is_equal_approx(audio.music.volume_db, float(audio.settings.music_db)), "music returns after announcer stops")

	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	var match_audio: Node
	for child in arena.get_children():
		if child.get_script() == load("res://scripts/core/match_audio.gd"):
			match_audio = child
	match_audio.set_process(false)
	var spy := AudioSpy.new()
	spy.settings = audio.settings
	match_audio.GameAudio = spy
	arena.phase = &"PLAYING"
	match_audio._process(0.0)
	check(match_audio.crowd.playing and match_audio.crowd.stream != audio.stream_for("crowd_cheer") and (match_audio.crowd.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "crowd ambience loops a duplicate during PLAYING")
	var reaction: Node = arena.get_node("CrowdReaction")
	reaction.set_process(false)
	reaction.excitement = 0.0
	match_audio._process(0.0)
	var quiet: float = match_audio.crowd.volume_db
	reaction.excitement = 1.0
	match_audio._process(0.0)
	check(match_audio.crowd.volume_db > quiet and match_audio.crowd.pitch_scale < 1.0, "crowd grows with presentation excitement at a lower pitch")
	arena.remove_child(reaction)
	match_audio._process(0.0)
	check(is_equal_approx(match_audio.crowd.volume_db, quiet), "legacy scenes without CrowdReaction retain quiet ambience")
	arena.add_child(reaction)
	arena.paused = true
	match_audio._process(0.0)
	check(match_audio.crowd.stream_paused, "pause suspends the crowd loop")
	arena.paused = false
	match_audio._process(0.0)
	check(not match_audio.crowd.stream_paused, "resume restores the crowd loop")
	spy.cues.clear()
	arena.player.position = Vector3.ZERO
	arena.opponent.position = Vector3(GameBalance.get_number("arena_rx") - 0.1, 0.0, 0.0)
	check(arena.presentation_pinned(arena.opponent), "fence test fixture is pinned")
	match_audio._process(0.01)
	match_audio._process(0.01)
	check(spy.cues.count("wooden_fence_rattle") == 1, "PINNED rising edge rattles once while held")
	arena.opponent.position = Vector3(3, 0, 0)
	match_audio._process(0.01)
	arena.opponent.position = Vector3(GameBalance.get_number("arena_rx") - 0.1, 0, 0)
	match_audio._process(0.01)
	check(spy.cues.count("wooden_fence_rattle") == 1, "second edge inside the cooldown stays silent")
	arena.opponent.position = Vector3(3, 0, 0)
	match_audio._process(float(audio.settings.pinned_rattle_cooldown_s))
	arena.opponent.position = Vector3(GameBalance.get_number("arena_rx") - 0.1, 0, 0)
	match_audio._process(0.01)
	check(spy.cues.count("wooden_fence_rattle") == 2, "new edge after cooldown rattles again")
	spy.cues.clear()
	arena.player.position = Vector3(0, 0, 0.8)
	arena.opponent.position = Vector3(0, 0, -0.8)
	arena.player.reset_combat()
	arena.opponent.reset_combat()
	arena.player.facing = Vector3.FORWARD
	arena.opponent.facing = Vector3.BACK
	var guard := InputFrame.new(2)
	guard.guard_held = true
	arena.opponent.begin_input(guard)
	arena.player.attack_kind = &"HORN"
	arena.combat.apply_hit(arena.player, arena.opponent)
	check(spy.cues.count("buffalo_block") == 1 and spy.cues.count("buffalo_horn_hit") == 0, "resolver GUARD_HIT then HORN_HIT produces one block sound")
	spy.cues.clear()
	arena.combat_event.emit(&"CLASH_HOOK", 1, 2, 0.0)
	check(spy.cues == ["clash_hook"], "CLASH_HOOK uses its short low horn cue")
	spy.cues.clear()
	arena.opponent.state = Buffalo.State.FLEE
	arena.phase = &"RESULT"
	match_audio._process(0.0)
	check(spy.cues.count("crowd_cheer") == 1 and spy.cues.count("festival_gong") == 1 and match_audio.crowd.playing, "FLEE and RESULT in one frame produce a single cheer and retain result ambience")
	match_audio._process(0.0)
	check(spy.cues.count("crowd_cheer") == 1, "sustained FLEE and RESULT do not repeat the cheer")
	arena.combat_event.emit(&"COUNTER_HIT", 1, 2, 0.0)
	check(spy.cues.count("crowd_cheer") == 1, "counter and result cheer cannot overlap in one presentation frame")
	match_audio.GameAudio = audio
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	arena.free()
	spy.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	var real_after := FileAccess.get_file_as_bytes(real_path) if FileAccess.file_exists(real_path) else PackedByteArray()
	check(real_before == real_after, "test leaves the player's settings file unchanged")
	await physics_frame
	await physics_frame
	print("%d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
