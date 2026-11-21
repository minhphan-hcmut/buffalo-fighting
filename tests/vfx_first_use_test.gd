extends SceneTree
## First-use stalls on integrated GPUs (2026-11-22): the warm-up must draw every floating
## word and a furrow, and impact lights must come from a fixed pool that never leaves the
## scene (a new omni light cost ~25 ms on each hit on Intel Iris Xe).

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func run() -> void:
	SessionState.mode = &"SOLO"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	for frame in GameBalance.get_int("vfx_warm_up_settle_frames") + 1:
		await process_frame
	var warm := arena.vfx.get_node_or_null("WarmUp")
	var label := (arena.player.get_node("CombatFeedback") as BuffaloFeedback).label
	var other := (arena.opponent.get_node("CombatFeedback") as BuffaloFeedback).label
	# Overlap avoidance may hide the older of the two; one drawn label compiles everything.
	var words_shown := label.visible or other.visible
	for word in BuffaloFeedback.WORDS.values():
		words_shown = words_shown and label.text.contains(word) and other.text.contains(word)
	check(words_shown, "warm-up shows every floating combat word: '%s'" % label.text)
	var furrows := 0
	if warm != null:
		for child in warm.get_children():
			if child is MeshInstance3D:
				furrows += 1
	check(furrows > 0, "warm-up draws a furrow mark")
	for frame in GameBalance.get_int("vfx_warm_up_frames") + 2:
		await process_frame
	check(not label.visible and not other.visible, "floating words are hidden again after the warm-up")

	var pool := arena.vfx.lights.get_children()
	check(pool.size() == GameBalance.get_int("vfx_max_lights"), "impact lights are a pool of vfx_max_lights before any hit")
	for event in [&"HORN_HIT", &"DASH_HIT", &"PARRY_SUCCESS"]:
		arena.combat_event.emit(event, 1, 2, 0.0)
		await process_frame
	check(arena.vfx.lights.get_children() == pool, "hits reuse the pooled lights instead of adding new ones")
	check(arena.vfx.active_lights().size() > 0, "a hit lights a pooled light")
	arena.vfx._process(GameBalance.get_number("vfx_light_s") * 2.0)
	await process_frame
	check(arena.vfx.lights.get_children() == pool and arena.vfx.active_lights().is_empty(), "faded lights stay in the scene, dark")
	arena.queue_free()
	await process_frame
	print("VFX first use: %d failures" % failures)
	quit(0 if failures == 0 else 1)
