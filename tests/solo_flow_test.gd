extends SceneTree
## Real scene/button regressions for the extracted menu presenters and Solo coordinator.

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
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.return_to_menu()
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	(menu.menu_layout.get_node("SoloButton") as Button).pressed.emit()
	check(menu.get_node_or_null("SoloModeView") != null, "real Solo button uses the scene-owned mode presenter")
	var old_page: WeakRef = weakref(menu.solo_page)
	(menu.solo_page.find_child("TrainingButton", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	check(old_page.get_ref() == null, "replacing chooser releases its old page and callbacks")
	check(menu.solo_page.find_child("dummy", true, false).has_focus(), "training replacement focuses the first live row")
	(menu.solo_page.find_child("SoloBack", true, false) as Button).pressed.emit()
	await process_frame
	check(menu.solo_page.find_child("SeasonButton", true, false).has_focus(), "back from training focuses the recreated season choice")
	var page_ref: WeakRef = weakref(menu.solo_page)
	menu.free()
	await process_frame
	check(page_ref.get_ref() == null, "freeing menu releases mode page and focus callbacks")
	await _result_lifecycle()
	await _season_transitions()
	SessionState.return_to_menu()
	print("SOLO FLOW TEST FAILURES: ", failures)
	quit(1 if failures else 0)


func _overlay() -> Control:
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.name = "SoloSessionOverlay"
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	return overlay


func _result_lifecycle() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://solo_flow_notebook.json"))
	CultureCards.load_notebook("user://solo_flow_notebook.json")
	SessionState.begin_solo()
	SessionState.last_winner = 1
	SessionState.last_reason = &"TIME"
	var overlay := _overlay()
	overlay._show_result("hidden")
	check(overlay.get_node_or_null("SoloResultView") != null, "overlay builds a scene-owned result presenter")
	var card := overlay.find_child("CultureCard", true, false) as Control
	var card_id: StringName = card.get_meta("card_id")
	check(not CultureCards.has_seen(card_id), "hidden result does not award its notebook card")
	overlay.show()
	await process_frame
	check(CultureCards.has_seen(card_id), "making result visible awards its card")
	var count := CultureCards.notebook_seen.size()
	overlay.hide()
	overlay.show()
	overlay._show_result("hidden")
	await process_frame
	check(CultureCards.notebook_seen.size() == count and SessionState.culture_cards_seen.size() == 1, "visibility toggles and duplicate result do not double-award")
	var view_ref: WeakRef = weakref(overlay.get_node_or_null("SoloResultView"))
	var tween: Tween = overlay.result_tween
	overlay.free()
	scene_changed.emit()
	await process_frame
	check(view_ref.get_ref() == null and not tween.is_valid(), "free during result animation kills presenter tween and scene callback")
	SessionState.last_match_level = &"L05"
	overlay = _overlay()
	overlay.show()
	overlay._show_result("final")
	var closing := overlay.find_child("Ceremony", true, false) as CeremonyView
	check(closing != null and not overlay.result_panel.visible, "final result is hidden while closing rite owns focus")
	var closing_ref: WeakRef = weakref(closing)
	overlay.free()
	scene_changed.emit()
	await process_frame
	check(closing_ref.get_ref() == null, "free during closing rite releases focus callback and ceremony")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://solo_flow_notebook.json"))
	CultureCards.load_notebook()


func _settle_arena() -> MatchController:
	var arena := current_scene as MatchController
	arena.set_physics_process(false)
	for frame in 6:
		await process_frame
	return arena


func _finish(arena: MatchController, winner: int) -> Control:
	arena._finish(winner, &"TIME")
	var skip := InputEventKey.new()
	skip.pressed = true
	skip.keycode = KEY_A
	arena.outro.time = GameBalance.get_number("result_skip_grace_s")
	arena.outro.skip(skip)
	var overlay := root.get_node("SoloSessionOverlay") as Control
	overlay._process(0.0)
	return overlay


func _season_transitions() -> void:
	SessionState.return_to_menu()
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._show_solo_chooser()
	(menu.solo_page.find_child("SeasonButton", true, false) as Button).pressed.emit()
	check(menu.get_node_or_null("SoloFlow") != null, "season event is coordinated by a scene-owned SoloFlow")
	check(menu.ceremony_layer.variant == &"opening", "season begins with opening rite")
	(menu.ceremony_layer as CeremonyView).finish()
	check(menu.ceremony_layer.variant == &"water", "opening sequences directly into water rite")
	(menu.ceremony_layer as CeremonyView).finish()
	await scene_changed
	var arena := await _settle_arena()
	var overlay := _finish(arena, 2)
	var identity := overlay.get_instance_id()
	(overlay.result_actions.get_child(0) as Button).pressed.emit()
	await scene_changed
	arena = await _settle_arena()
	check(arena.level_id == &"L01" and SessionState.unlocked_level == 1 and SessionState.last_winner == 0, "loss retry restarts qualifier without progressing or replaying rites")
	for index in SessionState.SOLO_LEVELS.size():
		check(arena.level_id == SessionState.SOLO_LEVELS[index], "actual season transition mounts %s" % SessionState.SOLO_LEVELS[index])
		overlay = _finish(arena, 1)
		check(overlay.get_instance_id() == identity and overlay.get_meta("session_overlay"), "season retains root overlay identity/meta")
		if index == SessionState.SOLO_LEVELS.size() - 1:
			var closing := overlay.find_child("Ceremony", true, false) as CeremonyView
			check(closing != null and not overlay.result_panel.visible, "final win sequences closing before result")
			closing.finish()
			check(overlay.result_actions.get_child_count() == 2, "final result offers retry/menu only")
			break
		(overlay.result_actions.get_child(0) as Button).pressed.emit()
		if index in [1, 3]:
			check(SessionState.last_winner == 1 and not overlay.result_panel.visible, "next rite retains old result until rite completes")
			(overlay.ceremony_layer as CeremonyView).finish()
		await scene_changed
		arena = await _settle_arena()
	check(SessionState.rites_seen == [&"water", &"giap", &"drums"] and SessionState.unlocked_level == 5, "real five-round season consumes rites once and unlocks exactly five rounds")
	# Exit with an actual next-round rite still active, then recreate the overlay.
	SessionState.last_match_level = &"L02"
	SessionState.level_id = &"L03"
	SessionState.rites_seen.erase(&"giap")
	overlay._show_result("leave-during-next")
	(overlay.result_actions.get_child(0) as Button).pressed.emit()
	var rite_ref: WeakRef = weakref(overlay.ceremony_layer)
	var flow_ref: WeakRef = weakref(overlay.get_node("SoloFlow"))
	overlay.free()
	scene_changed.emit()
	await process_frame
	check(rite_ref.get_ref() == null and flow_ref.get_ref() == null, "free during next rite releases coordinator and pending continuation")
	overlay = _overlay()
	check(overlay.displayed_result.is_empty() and overlay.ceremony_layer == null, "recreated overlay has no stale result/rite/focus target")
	arena.free()
	overlay.free()
	await process_frame
