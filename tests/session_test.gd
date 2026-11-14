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
	SessionState.return_to_menu()
	var show_opening := SessionState.begin_solo()
	check(show_opening and SessionState.level_id == &"L01", "new solo session opens at L01 with ceremony")
	check(SessionState.advance_after_win(), "L01 win unlocks next round")
	check(SessionState.level_id == &"L02" and SessionState.last_match_level == &"L01", "L02 unlock retains retry target")
	check(SessionState.advance_after_win(), "L02 win unlocks final round")
	check(SessionState.level_id == &"L03", "L03 becomes current round")
	SessionState.retry()
	check(SessionState.level_id == &"L02", "retry returns to the most recently completed round")
	SessionState.return_to_menu()
	check(SessionState.level_id == &"L01" and SessionState.unlocked_level == 1, "returning to menu resets session progress")
	_check_rites()
	await _check_rite_flow()
	print("SESSION TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


## GDD Bảng 17 SHOULD rites: one per round, in festival order, each shown once per run.
func _check_rites() -> void:
	SessionState.return_to_menu()
	SessionState.begin_solo()
	check(SessionState.take_rites_before(&"L01") == [&"water"], "rước nước plays before the qualifier")
	check(SessionState.take_rites_before(&"L01").is_empty(), "a retried qualifier does not replay its rite")
	check(SessionState.take_rites_before(&"L02") == [&"giap"] and SessionState.take_rites_before(&"L03") == [&"drums"], "giáp procession before the semi-final, drums before the final")
	SessionState.return_to_menu()
	SessionState.begin_solo()
	check(SessionState.take_rites_before(&"L02") == [&"giap"], "a new festival run shows the rites again")
	SessionState.mode = &"LAN"
	check(SessionState.take_rites_before(&"L03").is_empty(), "LAN matches have no rites")
	SessionState.return_to_menu()


## Starting Solo from the menu plays the opening rite, then rước nước, then enters the arena.
func _check_rite_flow() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._start_solo()
	await process_frame
	var first := menu.ceremony_layer as CeremonyView
	check(first != null and first.variant == &"opening", "Solo opens with the opening rite")
	first.finish()
	await process_frame
	var second := menu.ceremony_layer as CeremonyView
	check(second != null and second.variant == &"water", "rước nước follows the opening rite")
	second.finish()
	await process_frame
	await process_frame
	check(current_scene is MatchController, "the qualifier starts after the rites")
	SessionState.return_to_menu()
