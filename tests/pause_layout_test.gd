extends SceneTree
## Every in-match pause panel (pause, settings, LAN wait, LAN confirmation) must sit centred
## inside the overlay, fully on screen.

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func check_centered(hud: CanvasLayer, screen: String) -> void:
	await process_frame
	var overlay: Rect2 = hud.pause_overlay.get_global_rect()
	var panel: Rect2 = hud.pause_panel.get_global_rect()
	check(overlay.encloses(panel), "%s panel lies fully inside the screen (panel %s, screen %s)" % [screen, panel, overlay])
	check(panel.get_center().distance_to(overlay.get_center()) < 1.0, "%s panel is centred (panel centre %s, screen centre %s)" % [screen, panel.get_center(), overlay.get_center()])


func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	var hud: CanvasLayer = arena.hud
	hud.show_pause()
	await check_centered(hud, "pause")
	hud.show_settings()
	await check_centered(hud, "settings")
	hud.show_pause()
	await check_centered(hud, "pause after settings")
	hud.show_pause_wait(true)
	await check_centered(hud, "LAN wait")
	hud.show_pause_confirmation(2, true)
	await check_centered(hud, "LAN confirmation")
	print("PAUSE LAYOUT TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
