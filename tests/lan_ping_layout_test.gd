extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	var label: Label = arena.hud.ping_label
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 600)]:
		root.size = size
		await process_frame
		var bounds := label.get_global_rect()
		var margin := GameBalance.get_number("hud_ping_margin_px")
		var viewport := root.get_visible_rect()
		if not viewport.encloses(bounds) or not bounds.end.is_equal_approx(viewport.end - Vector2.ONE * margin):
			failures += 1
			push_error("LAN ping must stay inside the bottom-right margin at %s: %s" % [size, bounds])
	arena.queue_free()
	await process_frame
	print("LAN PING LAYOUT: ", failures, " failures")
	quit(0 if failures == 0 else 1)
