extends SceneTree
## Client half of the two-process LAN CLASH check. Prints what the client HUD and buffaloes show.

const PORT := 47932

var arena: MatchController


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var manager: Node = root.get_node("NetworkManager")
	manager.join("127.0.0.1", PORT)
	var timer := create_timer(25.0)
	timer.timeout.connect(func(): print("CLIENT: timed out"); quit(1))
	await manager.lobby_ready
	SessionState.mode = &"LAN"
	arena = load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	var frame := 0
	var panel_frames := 0
	var saw_bar := false
	var best_bar := 0.0
	while frame < 900 and arena.phase != &"RESULT":
		await physics_frame
		frame += 1
		var hud = arena.hud
		if hud != null and hud.clash_panel.visible:
			panel_frames += 1
			saw_bar = true
			best_bar = hud.clash_bar.value
			if panel_frames % 6 == 1:
				print("C panel visible bar=%.1f time='%s' hook='%s' title='%s' %s" % [hud.clash_bar.value, hud.clash_time_label.text, hud.clash_hook_label.text, hud.clash_title.text, _line()])
		elif frame % 60 == 0 and arena.phase == &"PLAYING":
			print("C ", _line())
	print("CLIENT bar_seen=%s panel_frames=%d last_bar=%.1f" % [saw_bar, panel_frames, best_bar])
	print("CLIENT FINAL ", _line())
	manager.leave()
	quit(0)


func _line() -> String:
	return "st=%s/%s facing=(%.2f,%.2f)/(%.2f,%.2f) rotY=%.2f/%.2f x=%.2f/%.2f spirit=%.0f/%.0f clash=%s" % [
		arena.player.state_name(), arena.opponent.state_name(),
		arena.player.facing.x, arena.player.facing.z, arena.opponent.facing.x, arena.opponent.facing.z,
		arena.player.rotation.y, arena.opponent.rotation.y,
		arena.player.position.x, arena.opponent.position.x, arena.player.spirit, arena.opponent.spirit,
		not arena.active_clash.is_empty()
	]
