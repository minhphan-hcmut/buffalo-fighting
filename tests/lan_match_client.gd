extends SceneTree
## Client half of the two-process LAN CLASH check. Prints what the client HUD and buffaloes show.

const PORT := 47932

var arena: MatchController
var failures := 0


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
	var clash_was_visible := false
	var post_clash_ticks := 0
	var saw_post_clash_stun := false
	var facing_ok := true
	var playing_spirit := Vector2.ZERO
	var playing_states_normal := false
	while frame < 900 and arena.phase != &"RESULT":
		await physics_frame
		frame += 1
		if arena.phase == &"PLAYING":
			playing_spirit = Vector2(arena.player.spirit, arena.opponent.spirit)
			playing_states_normal = arena.player.state == Buffalo.State.NORMAL and arena.opponent.state == Buffalo.State.NORMAL and arena.active_clash.is_empty()
		var hud = arena.hud
		if clash_was_visible and arena.active_clash.is_empty():
			post_clash_ticks += 1
			if post_clash_ticks <= 30 and arena.opponent.state == Buffalo.State.STUNNED:
				saw_post_clash_stun = true
		if hud != null and hud.clash_panel.visible:
			clash_was_visible = true
			facing_ok = facing_ok and arena.player.facing.distance_to(Vector3.RIGHT) < 0.05 and arena.opponent.facing.distance_to(Vector3.LEFT) < 0.05
			panel_frames += 1
			saw_bar = true
			best_bar = hud.clash_bar.value
			if panel_frames % 6 == 1:
				print("C panel visible bar=%.1f time='%s' hook='%s' title='%s' %s" % [hud.clash_bar.value, hud.clash_time_label.text, hud.clash_hook_label.text, hud.clash_title.text, _line()])
		elif frame % 60 == 0 and arena.phase == &"PLAYING":
			print("C ", _line())
	print("CLIENT bar_seen=%s panel_frames=%d last_bar=%.1f" % [saw_bar, panel_frames, best_bar])
	print("CLIENT FINAL ", _line())
	check(saw_bar, "client saw the KHÓA SỪNG bar")
	check(absf(best_bar - (-70.0)) < 0.5, "client bar shows -70 (mirrored for slot 2), last value %.1f" % best_bar)
	check(facing_ok and arena.player.facing.distance_to(Vector3.RIGHT) < 0.05 and arena.opponent.facing.distance_to(Vector3.LEFT) < 0.05, "client facing is +X / -X during and after the CLASH")
	check(is_equal_approx(playing_spirit.x, 100.0) and is_equal_approx(playing_spirit.y, 86.0), "client SPIRIT after the CLASH is 100/86")
	check(saw_post_clash_stun, "client shows the loser STUNNED right after the CLASH")
	check(playing_states_normal, "client states are NORMAL/NORMAL with no CLASH before the match ends")
	check(arena.end_reason == &"FLEE" and arena.winner_slot == 1, "client receives RESULT: slot 1 wins by FLEE (got %s / %d)" % [arena.end_reason, arena.winner_slot])
	manager.leave()
	print("LAN CLIENT FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _line() -> String:
	return "st=%s/%s facing=(%.2f,%.2f)/(%.2f,%.2f) rotY=%.2f/%.2f x=%.2f/%.2f spirit=%.0f/%.0f clash=%s" % [
		arena.player.state_name(), arena.opponent.state_name(),
		arena.player.facing.x, arena.player.facing.z, arena.opponent.facing.x, arena.opponent.facing.z,
		arena.player.rotation.y, arena.opponent.rotation.y,
		arena.player.position.x, arena.opponent.position.x, arena.player.spirit, arena.opponent.spirit,
		not arena.active_clash.is_empty()
	]
