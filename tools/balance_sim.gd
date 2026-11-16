extends SceneTree
## Mô phỏng phân tích, không ghi balance: --matches=200 --level=L01 --pair=NORMAL,HARD
## --set=horn_damage=16 --output=res://.scratch/orca/balance-ping-2026-11-16/balance.json

const OUTPUT := "res://.scratch/orca/balance-ping-2026-11-16/balance.json"

class Simulation extends RefCounted:
	var match_node: MatchController
	var actors: Array[Buffalo] = []
	var bots: Array[Node] = []
	var moves: Array[Dictionary] = []
	var damage: Array[Dictionary] = []
	var annotations: Array[Dictionary] = []
	var guard_connected := [false, false]
	var release_now := [false, false]
	var spirit_before := [0.0, 0.0]
	var last_hit_loss := [0.0, 0.0]
	var hook_started := [false, false]
	var profiles: Dictionary

	func _init(parent: Node) -> void:
		profiles = DataFile.load_json("res://data/ai_profiles.json")
		SessionState.hitstop_enabled = true
		SessionState.auto_pause_enabled = false
		SessionState.replay_enabled = false
		SessionState.camera_shake_enabled = false
		SessionState.mode = &"SOLO"
		SessionState.level_id = &"L01"
		SessionState.training = false
		match_node = load("res://scenes/arena.tscn").instantiate() as MatchController
		parent.add_child(match_node)
		match_node.set_process(false)
		match_node.set_physics_process(false)
		match_node.set_process_input(false)
		for node in match_node.find_children("*", "Node", true, false):
			node.set_process(false)
			node.set_physics_process(false)
		for signal_name in ["combat_event", "resource_changed", "match_ended"]:
			for connection in match_node.get_signal_connection_list(signal_name):
				if signal_name != "combat_event" or connection.callable != match_node._on_combat_event:
					match_node.disconnect(signal_name, connection.callable)
		match_node.ai.free()
		match_node.ai = null
		match_node.vfx.free()
		match_node.vfx = null
		match_node.replay.free()
		match_node.replay = null
		# Skip only the already-decided outro; all finish rules still execute in MatchController.
		match_node.outro.running = true
		for actor: Buffalo in [match_node.player, match_node.opponent]:
			var visual := actor.get_node("Visual")
			actor.remove_child(visual)
			visual.free()
			var empty := Node3D.new()
			empty.name = "Visual"
			actor.add_child(empty)
			actor.visual = empty
			actors.append(actor)
		match_node.combat_event.connect(_event)

	func dispose() -> void:
		match_node.free()

	func _event(event: StringName, source: int, target: int, _value: float) -> void:
		var index := source - 1
		var meter := moves[index]
		if event in [&"HORN_START", &"COUNTER_START", &"DASH_START", &"PARRY_START"]:
			var kind := "dash" if event == &"DASH_START" else ("parry" if event == &"PARRY_START" else "horn")
			meter[kind].uses += 1
			meter[kind].opportunities += 1
			if kind in ["horn", "dash"]:
				meter.flank.opportunities += 1
				meter.back.opportunities += 1
		elif event == &"CLASH_START":
			for side in moves:
				side.clash.uses += 1
				side.clash.opportunities += 1
		elif event == &"CLASH_HOOK":
			hook_started[index] = true
			meter.hook.uses += 1
			meter.hook.opportunities += 1
		elif event == &"RELEASE_START":
			meter.release.uses += 1
			meter.release.opportunities += 1
			release_now[index] = true
		elif event == &"PARRY_SUCCESS":
			meter.parry.hits += 1
		elif event == &"GUARD_HIT" and not guard_connected[target - 1]:
			moves[target - 1].guard.hits += 1
			guard_connected[target - 1] = true
		elif event in [&"HORN_HIT", &"DASH_HIT", &"CLASH_LOSS"]:
			var kind := "horn" if event == &"HORN_HIT" else ("dash" if event == &"DASH_HIT" else "clash")
			meter[kind].hits += 1
			var lost := maxf(0.0, spirit_before[target - 1] - actors[target - 1].spirit)
			spirit_before[target - 1] = actors[target - 1].spirit
			damage[index][kind] += lost
			last_hit_loss[index] = lost
			if event == &"CLASH_LOSS" and release_now[index]:
				meter.release.hits += 1
		elif event in [&"FLANK_HIT", &"BACK_HIT", &"COUNTER_HIT"]:
			var kind := "flank" if event == &"FLANK_HIT" else ("back" if event == &"BACK_HIT" else "counter")
			annotations[index][kind] += last_hit_loss[index]
			if kind != "counter":
				meter[kind].uses += 1
				meter[kind].hits += 1

	func run_match(level: String, a: String, b: String, seed_value: int) -> Dictionary:
		for bot in bots:
			bot.free()
		bots.clear()
		moves.clear()
		damage.clear()
		annotations.clear()
		match_node.clash.active.clear()
		match_node.clash.cooldown = 0.0
		match_node.level_id = StringName(level)
		match_node.mud_zones.assign(DataFile.load_json("res://data/levels.json")[level].mud_zones)
		match_node.finished = false
		match_node.winner_slot = 0
		match_node.end_reason = &"NONE"
		match_node.hitstop_ticks = 0
		match_node.tick = 0
		match_node.match_seed = seed_value
		var names := [a, b]
		for side in 2:
			var actor := actors[side]
			actor.position = Vector3((-1.0 if side == 0 else 1.0) * GameBalance.get_number("buffalo_spawn_offset_x"), 0, 0)
			actor.rotation.y = -PI * 0.5 if side == 0 else PI * 0.5
			actor.reset_combat()
			actor.clash_hooked = false
			actor.clash_hook_time = 0.0
			actor.clash_release_pressed = false
			actor.clash_action = &"PUSH"
			actor.input_frame = InputFrame.new(side + 1)
			var bot := Node.new()
			bot.set_script(load("res://scripts/ai/ai_controller.gd"))
			bot.actor = actor
			bot.target = actors[1 - side]
			bot.profile = StringName(names[side])
			match_node.add_child(bot)
			bot.rng.seed = seed_value * 2 + side
			bots.append(bot)
			var meter := {}
			for kind in ["horn", "dash", "guard", "parry", "clash", "hook", "release", "flank", "back"]:
				meter[kind] = {"uses": 0, "opportunities": 0, "hits": 0}
			moves.append(meter)
			damage.append({"horn": 0.0, "dash": 0.0, "clash": 0.0})
			annotations.append({"counter": 0.0, "flank": 0.0, "back": 0.0})
			guard_connected[side] = false
			spirit_before[side] = actor.spirit
		match_node.start_playing()
		var delta := 1.0 / Engine.physics_ticks_per_second
		var pinned := [0.0, 0.0]
		var empty := [0.0, 0.0]
		while not match_node.finished:
			release_now.assign([false, false])
			hook_started.assign([false, false])
			var guarding := [actors[0].guarding, actors[1].guarding]
			var hooked := [actors[0].clash_hooked, actors[1].clash_hooked]
			var hook_time := [actors[0].clash_hook_time, actors[1].clash_hook_time]
			var advancing := match_node.hitstop_ticks == 0 and match_node.clash.is_active()
			# Both AIs observe the same pre-tick state; the real controller handles buffers/hitstop.
			var frame_a: InputFrame = bots[0].build_input(delta)
			var frame_b: InputFrame = bots[1].build_input(delta)
			frame_a.player_slot = 1
			match_node.simulate_tick(delta, frame_a, frame_b)
			for side in 2:
				if advancing and not release_now.has(true) and hooked[side] and hook_time[side] <= delta and not hooked[1 - side] and not hook_started[1 - side]:
					moves[side].hook.hits += 1
				if actors[side].guarding and not guarding[side]:
					moves[side].guard.uses += 1
					moves[side].guard.opportunities += 1
				if not actors[side].guarding:
					guard_connected[side] = false
				if actors[side].stamina <= 0.0:
					empty[side] += delta
				if match_node.presentation_pinned(actors[side]):
					pinned[side] += delta
		return {"winner": match_node.winner_slot, "reason": String(match_node.end_reason), "seconds": match_node.tick * delta, "active_seconds": GameBalance.get_number("match_duration_s") - match_node.remaining_time, "moves": moves.duplicate(true), "damage": damage.duplicate(true), "annotations": annotations.duplicate(true), "pinned_seconds": pinned, "empty_seconds": empty, "spirit": [actors[0].spirit, actors[1].spirit]}


static func interval(wins: int, count: int) -> Array:
	var z := 1.959963984540054
	var p := float(wins) / count
	var denom := 1.0 + z * z / count
	var middle := (p + z * z / (2.0 * count)) / denom
	var half := z * sqrt(p * (1.0 - p) / count + z * z / (4.0 * count * count)) / denom
	return [middle - half, middle + half]


static func summarize(results: Array[Dictionary]) -> Dictionary:
	var row := {"matches": results.size(), "wins": [0, 0], "reasons": {"FLEE": 0, "TIME": 0, "LOT": 0}, "moves": results[0].moves.duplicate(true), "damage": [{"horn": 0.0, "dash": 0.0, "clash": 0.0}, {"horn": 0.0, "dash": 0.0, "clash": 0.0}], "annotations": [{"counter": 0.0, "flank": 0.0, "back": 0.0}, {"counter": 0.0, "flank": 0.0, "back": 0.0}], "pinned_seconds": [0.0, 0.0], "empty_seconds": [0.0, 0.0]}
	for side in row.moves:
		for meter in side.values():
			for key in meter:
				meter[key] = 0
	var lengths: Array[float] = []
	for result in results:
		row.wins[result.winner - 1] += 1
		row.reasons[result.reason] += 1
		lengths.append(result.seconds)
		for side in 2:
			row.pinned_seconds[side] += result.pinned_seconds[side]
			row.empty_seconds[side] += result.empty_seconds[side]
			for kind in row.damage[side]:
				row.damage[side][kind] += result.damage[side][kind]
			for kind in row.annotations[side]:
				row.annotations[side][kind] += result.annotations[side][kind]
			for kind in row.moves[side]:
				for key in row.moves[side][kind]:
					row.moves[side][kind][key] += result.moves[side][kind][key]
	lengths.sort()
	row.length = {"mean": lengths.reduce(func(total: float, value: float): return total + value, 0.0) / lengths.size(), "median": (lengths[(lengths.size() - 1) / 2] + lengths[lengths.size() / 2]) * 0.5, "p90": lengths[ceili(lengths.size() * 0.9) - 1]}
	row.win_rates = [float(row.wins[0]) / results.size(), float(row.wins[1]) / results.size()]
	row.win_ci95 = [interval(row.wins[0], results.size()), interval(row.wins[1], results.size())]
	for side in row.moves:
		for meter in side.values():
			meter.hit_rate = float(meter.hits) / meter.opportunities if meter.opportunities > 0 else null
	return row


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var matches := 200
	var base_seed := 20261116
	var selected_level := ""
	var selected_pair := ""
	var swap_sides := false
	var output := OUTPUT
	var overrides := {}
	var balance := DataFile.load_json("res://data/balance.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			matches = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--seed="):
			base_seed = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--level="):
			selected_level = arg.get_slice("=", 1)
		elif arg.begins_with("--pair="):
			selected_pair = arg.get_slice("=", 1)
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--swap-sides":
			swap_sides = true
		elif arg.begins_with("--set="):
			var setting := arg.trim_prefix("--set=").split("=")
			if setting.size() != 2 or not balance.has(setting[0]) or not setting[1].is_valid_float() or not is_finite(float(setting[1])):
				push_error("Invalid in-memory balance override: " + arg)
				quit(1)
				return
			overrides[setting[0]] = float(setting[1])
		else:
			push_error("Unknown argument: " + arg)
			quit(1)
			return
	if matches <= 0:
		quit(1)
		return
	GameBalance._load_values()
	for key in overrides:
		GameBalance.values[key] = overrides[key]
	var simulation := Simulation.new(root)
	var profiles: Array = DataFile.load_json("res://data/ai_profiles.json").keys()
	profiles.sort()
	var document := {"matches_per_pair": matches, "base_seed": base_seed, "engine": Engine.get_version_info().string, "balance_sha256": FileAccess.get_sha256("res://data/balance.json"), "overrides": overrides, "swap_sides": swap_sides, "profiles": profiles, "tick_hz": Engine.physics_ticks_per_second, "rows": []}
	var row_index := 0
	var started := Time.get_ticks_msec()
	for level: StringName in SessionState.SOLO_LEVELS:
		for a: String in profiles:
			for b: String in profiles:
				var first_seed := base_seed + row_index * matches
				row_index += 1
				if (not selected_level.is_empty() and selected_level != String(level)) or (not selected_pair.is_empty() and selected_pair != "%s,%s" % [a, b]):
					continue
				await physics_frame
				var results: Array[Dictionary] = []
				var side_wins := [0, 0]
				for trial in matches:
					var reverse := swap_sides and trial >= matches / 2
					var result := simulation.run_match(String(level), b if reverse else a, a if reverse else b, first_seed + trial)
					side_wins[result.winner - 1] += 1
					if reverse:
						result.winner = 3 - result.winner
						for key in ["moves", "damage", "annotations", "pinned_seconds", "empty_seconds", "spirit"]:
							result[key].reverse()
					results.append(result)
				var row := summarize(results)
				row.physical_side_wins = side_wins
				row.level = String(level)
				row.profiles = [a, b]
				row.first_seed = first_seed
				document.rows.append(row)
				document.elapsed_s = (Time.get_ticks_msec() - started) / 1000.0
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
				var file := FileAccess.open(output, FileAccess.WRITE)
				if file == null:
					quit(1)
					return
				file.store_string(JSON.stringify(document, "\t"))
				file.close()
				print("BALANCE ", level, " ", a, "/", b, " n=", matches, " wins=", row.wins, " seconds=", document.elapsed_s)
	if document.rows.is_empty():
		push_error("No matching level/profile pair")
		quit(1)
		return
	simulation.dispose()
	quit(0)
