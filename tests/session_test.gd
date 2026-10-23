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
	print("SESSION TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
