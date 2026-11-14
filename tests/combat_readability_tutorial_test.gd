extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	var hud = arena.hud
	hud.set_process(false)
	var duration := GameBalance.get_number("tutorial_hint_s")
	arena.start_playing()
	hud._process(0.0)
	check(hud.tutorial_current == 1, "L01 PLAYING starts tutorial 1")
	arena.player.position = Vector3.ZERO
	arena.opponent.position = Vector3(0, 0, -4)
	hud._process(0.0)
	check(hud.tutorial_queue == [3], "first distance 3-5 m queues hint 3")
	arena.opponent.position.z = -2.9
	hud._process(0.0)
	check(hud.tutorial_queue == [2, 3], "triggered hints queue in numerical order")
	arena.player.facing = Vector3.FORWARD
	hud._tutorial_event(&"DASH_HIT", 2, 1, 14)
	hud._tutorial_event(&"HORN_HIT", 1, 2, 18)
	check(not hud.tutorial_front_hit and hud.tutorial_queue == [2, 3, 4], "first player hit queues 4; DASH/opponent hit cannot trigger 6")
	arena.player.facing = Vector3.RIGHT
	hud._tutorial_event(&"HORN_HIT", 2, 1, 23)
	check(not hud.tutorial_front_hit, "flank HORN does not trigger tutorial 6")
	arena.player.facing = Vector3.FORWARD
	hud._tutorial_event(&"HORN_HIT", 2, 1, 18)
	check(hud.tutorial_front_hit and not hud.tutorial_queue.has(6), "first front HORN waits for hint 4 to be shown")
	hud._tutorial_event(&"CLASH_START", 1, 2, 0)
	for id in [2, 3, 4, 5, 6]:
		hud._process(duration)
		check(hud.tutorial_current == id, "tutorial ordered display %d" % id)
	check(hud.tutorial_label.get_parsed_text() == "Bấm G đúng lúc để gạt sừng, rồi húc ngay để phản đòn", "exact tutorial 6 wording")
	hud._process(duration)
	hud._tutorial_event(&"HORN_HIT", 2, 1, 18)
	hud._tutorial_event(&"CLASH_START", 1, 2, 0)
	hud._process(duration)
	check(hud.tutorial_seen == [1, 2, 3, 4, 5, 6] and hud.tutorial_queue.is_empty(), "each context hint appears once")
	check(hud.tutorial_label.get_parsed_text().contains("G Gạt sừng"), "control guide includes G after hints")
	for variant in [[&"SOLO", &"L02"], [&"LAN", &"L01"]]:
		arena.mode = variant[0]
		arena.level_id = variant[1]
		hud.tutorial_seen.clear()
		hud._process(duration)
		hud._tutorial_event(&"HORN_HIT", 2, 1, 18)
		check(hud.tutorial_seen.is_empty() and hud.tutorial_queue.is_empty() and hud.tutorial_label.get_parsed_text().contains("G Gạt sừng"), "context hints only in SOLO L01")
	arena.free()
	print("READABILITY TUTORIAL FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
