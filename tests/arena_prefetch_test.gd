extends SceneTree
## Main menu starts loading the arena on a thread, so entering a match does not freeze.

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
	var arena := "res://scenes/arena.tscn"
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var status := ResourceLoader.load_threaded_get_status(arena)
	check(status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "main menu requests the arena on a background thread (status %d)" % status)
	var menu := current_scene
	menu.call("_go_to_arena")
	await process_frame
	await process_frame
	check(current_scene is MatchController, "entering the arena uses the prefetched scene")
	var cached = menu.get_script().get("_arena_scene") if is_instance_valid(menu) else load("res://scripts/ui/main_menu.gd").get("_arena_scene")
	check(cached is PackedScene, "arena scene is kept for retries")
	print("ARENA PREFETCH TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
