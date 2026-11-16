extends SceneTree

const SESSION = preload("res://scripts/core/session_state.gd")
const EXPECTED := [
	[&"L01", "Vòng loại", "EASY", [], "09", "GIÁP BẮC"],
	[&"L02", "Vòng hai", "EASY_PLUS", ["A"], "12", "GIÁP NAM"],
	[&"L03", "Tứ kết", "NORMAL", ["B"], "21", "GIÁP TRUNG"],
	[&"L04", "Bán kết", "NORMAL_PLUS", ["A", "B"], "03", "GIÁP THƯỢNG"],
	[&"L05", "Chung kết", "HARD", ["A", "B"], "17", "GIÁP TÂY"]
]
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
	var levels := DataFile.load_json("res://data/levels.json")
	var order := levels.keys().filter(func(id: String): return id != "LAN01" and id != "difficulty_labels")
	check(order == ["L01", "L02", "L03", "L04", "L05"], "data defines exactly five Solo rounds in order")
	check(SESSION.SOLO_LEVELS == [&"L01", &"L02", &"L03", &"L04", &"L05"], "session order matches all five data levels")
	for row in EXPECTED:
		var level: Dictionary = levels[row[0]]
		check([level.title, level.ai_profile, level.mud_zones, level.opponent_number, level.opponent_giap] == row.slice(1), "%s title, profile, mud and opponent match the approved table" % row[0])
		check(not String(level.description).is_empty(), "%s has a short description" % row[0])
	check(levels.LAN01.opponent_number == "17" and levels.LAN01.opponent_giap == "GIÁP TÂY", "LAN opponent keeps 17 and GIÁP TÂY in the same data fields")
	_check_progress()
	_check_rites()
	var profiles := DataFile.load_json("res://data/ai_profiles.json")
	_check_profile(profiles, "EASY_PLUS", "EASY", "NORMAL", {"reaction_s": 0.52, "guard": true, "strafe": false, "parry_chance": 0.05, "counter_chance": 0.25, "clash_weights": {"HOOK": 0.15, "RELEASE": 0.0}})
	_check_profile(profiles, "NORMAL_PLUS", "NORMAL", "HARD", {"reaction_s": 0.32, "guard": true, "strafe": true, "parry_chance": 0.25, "counter_chance": 0.65, "clash_weights": {"HOOK": 0.35, "RELEASE": profiles.HARD.clash_weights.RELEASE * 0.5}})
	for row in EXPECTED:
		await _check_arena_and_result(row, profiles)
	_check_loss()
	await _check_menu()
	SessionState.return_to_menu()
	print("FIVE LEVELS TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _check_progress() -> void:
	SESSION.return_to_menu()
	SESSION.begin_solo()
	for index in range(EXPECTED.size() - 1):
		var before: StringName = EXPECTED[index][0]
		var next: StringName = EXPECTED[index + 1][0]
		check(SESSION.level_id == before and SESSION.advance_after_win(), "%s win advances" % before)
		check(SESSION.level_id == next and SESSION.last_match_level == before and SESSION.unlocked_level == index + 2, "%s unlocks %s and retains the retry round" % [before, next])
	check(not SESSION.advance_after_win() and not SESSION.advance_after_win() and SESSION.level_id == &"L05" and SESSION.unlocked_level == 5, "winning L05 stops at the final without unlocking a sixth round")
	for index in EXPECTED.size():
		SESSION.return_to_menu()
		SESSION.unlocked_level = index + 1
		SESSION.begin_solo()
		SESSION.last_winner = 2
		SESSION.last_reason = &"TIME"
		SESSION.retry()
		check(SESSION.level_id == EXPECTED[index][0] and SESSION.unlocked_level == index + 1, "%s loss and retry stay on the same round" % EXPECTED[index][0])
		SESSION.begin_solo()
		check(SESSION.level_id == EXPECTED[index][0], "resuming after retry retains %s" % EXPECTED[index][0])
	SESSION.return_to_menu()
	SESSION.level_id = &"LAN01"
	check(not SESSION.advance_after_win(), "non-Solo round cannot advance through the season")
	SESSION.return_to_menu()


func _check_rites() -> void:
	SESSION.return_to_menu()
	SESSION.begin_solo()
	var expected := {&"L01": [&"water"], &"L03": [&"giap"], &"L05": [&"drums"]}
	for row in EXPECTED:
		check(SESSION.take_rites_before(row[0]) == expected.get(row[0], []), "%s plays only its mapped rite" % row[0])
		check(SESSION.take_rites_before(row[0]).is_empty(), "%s rite cannot replay on retry" % row[0])
	check(SESSION.rites_seen == [&"water", &"giap", &"drums"], "all three rites retain their festival order")
	SESSION.return_to_menu()
	SESSION.begin_solo()
	check(SESSION.take_rites_before(&"L03") == [&"giap"], "new season resets rite history")
	SESSION.mode = &"LAN"
	for row in EXPECTED:
		check(SESSION.take_rites_before(row[0]).is_empty(), "LAN never plays a Solo rite for %s" % row[0])
	SESSION.return_to_menu()


func _check_profile(profiles: Dictionary, name: String, base_name: String, upper_name: String, changes: Dictionary) -> void:
	var profile: Dictionary = profiles[name]
	var base: Dictionary = profiles[base_name]
	var upper: Dictionary = profiles[upper_name]
	check(profile.size() == base.size(), "%s keeps its base profile's full key set" % name)
	for field in base:
		check(profile.has(field) and profile[field] == changes.get(field, base[field]), "%s.%s matches the specified value or inherited base" % [name, field])
		if base[field] is float or base[field] is int:
			check(float(profile[field]) >= minf(base[field], upper[field]) and float(profile[field]) <= maxf(base[field], upper[field]), "%s.%s lies inclusively between neighbours" % [name, field])
	for field in ["HOOK", "RELEASE"]:
		check(float(profile.clash_weights[field]) >= minf(base.clash_weights[field], upper.clash_weights[field]) and float(profile.clash_weights[field]) <= maxf(base.clash_weights[field], upper.clash_weights[field]), "%s clash %s lies inclusively between neighbours" % [name, field])


func _check_arena_and_result(row: Array, profiles: Dictionary) -> void:
	SessionState.return_to_menu()
	SessionState.unlocked_level = EXPECTED.find(row) + 1
	SessionState.begin_solo()
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.hud.set_process(false)
	await process_frame
	check(arena.ai.profile == StringName(row[2]) and arena.ai.profile_data == profiles[row[2]], "%s loads its specified AI data in the unchanged FSM" % row[0])
	check(arena.ai.build_input(0.0) is InputFrame, "%s produces normal AI input" % row[0])
	check(arena.mud_zones.map(func(zone: StringName): return String(zone)) == row[3], "%s loads its mud zones" % row[0])
	var labels: Array = arena.hud.find_children("*", "Label", true, false).map(func(label: Label): return label.text)
	check(labels.has(row[4]) and labels.has("XANH · " + row[5]), "%s HUD reads opponent number and giáp from level data" % row[0])
	check(arena.announcer_text().begins_with(row[1]) and arena.announcer_text().contains("số %s cờ xanh %s" % [row[4], String(row[5]).capitalize()]), "%s opponent spawn and announcer use level data" % row[0])
	arena._finish(1, &"FLEE")
	arena.outro.time = GameBalance.get_number("result_skip_grace_s")
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	arena._input(key)
	var overlay := Control.new()
	overlay.name = "SoloSessionOverlay"
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	overlay._process(0.0)
	check(overlay._round_name(row[0]) == String(row[1]).to_upper(), "%s result round name matches its data title" % row[0])
	var closing := overlay.find_child("Ceremony", true, false) as CeremonyView
	if row[0] == &"L05":
		check(closing != null and closing.variant == &"closing" and not overlay.result_panel.visible, "only L05 victory opens the closing rite")
		if closing != null:
			closing.finish()
		check(overlay.result_panel.visible and overlay.result_title.text == "KHÉP MÙA HỘI" and overlay.result_actions.get_child_count() == 2, "L05 closing leads to the final result without a next-round button")
	else:
		var next_title: String = EXPECTED[EXPECTED.find(row) + 1][1]
		check(closing == null and overlay.result_panel.visible and overlay.result_title.text.begins_with("KẾT QUẢ"), "%s victory keeps the regular result, not the final ceremony" % row[0])
		check(overlay.result_actions.get_child(0).text == "TRẬN TIẾP THEO · " + next_title.to_upper(), "%s result offers the correct next round" % row[0])
	overlay.free()
	arena.free()
	await process_frame


func _check_loss() -> void:
	SessionState.return_to_menu()
	SessionState.unlocked_level = 4
	SessionState.begin_solo()
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena._finish(2, &"TIME")
	check(SessionState.level_id == &"L04" and SessionState.last_match_level == &"L04" and SessionState.unlocked_level == 4, "actual semi-final loss does not unlock the final")
	SessionState.retry()
	SessionState.begin_solo()
	check(SessionState.level_id == &"L04" and SessionState.last_winner == 0 and SessionState.last_reason == &"NONE", "retry after an actual loss restarts the same round with cleared result")
	arena.free()


func _check_menu() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var subtitle := menu.menu_layout.get_child(-1) as Label
	check(subtitle.text == "Vòng loại · Vòng hai · Tứ kết · Bán kết · Chung kết" and subtitle.get_line_count() == 1, "all five round names fit on one menu subtitle line")
	var font := subtitle.get_theme_font("font")
	var size := subtitle.get_theme_font_size("font_size")
	var full_width := font.get_string_size("Vòng loại · Vòng hai · Tứ kết · Bán kết · Chung kết", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	check(full_width <= menu.menu_layout.size.x, "all five round names fit within the left column")
	check(menu.menu_layout.get_global_rect().encloses(subtitle.get_global_rect()), "subtitle stays inside the menu column at 1280x720")
	print("SUBTITLE WIDTH full=", full_width, " column=", menu.menu_layout.size.x)
	menu.free()
