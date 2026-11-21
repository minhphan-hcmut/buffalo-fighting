extends SceneTree
## Repeatable Solo load; retains the real controller/input/snapshot/presentation paths.

class BotInput extends MatchInput:
	var fixture: SceneTree
	func read(slot: int, _yaw: float, _seq: int) -> InputFrame:
		return fixture.frame_for(slot)

class BotAI extends Node:
	var fixture: SceneTree
	func build_input(_delta: float) -> InputFrame:
		return fixture.frame_for(2)

var arena: MatchController
var recording := false
var seconds := 0.0
var duration := 180.0
var started := 0
var label := "before-low"
var low := true
var times := PackedFloat64Array()
var cpu := PackedFloat64Array()
var nodes := PackedInt32Array()
var emitters := PackedInt32Array()
var lights := PackedInt32Array()
var writes := PackedInt32Array()
var tags: Dictionary = {}
var seen_events: Dictionary = {}
var seen_emitters: Dictionary = {}
var last_horn := [-1, -1]
var last_dash := -1
var events: Dictionary = {}
var new_emitter_count := 0
var frame_begin := 0
var tick_begin := 0
var audio: FestivalAudio
var loaded_audio: Dictionary = {}
var playing_mask := 0


func _initialize() -> void:
	call_deferred("run")


func tag(value: String) -> void:
	if recording:
		var items: PackedStringArray = tags.get(times.size(), PackedStringArray())
		items.append(value)
		tags[times.size()] = items


func combat(event: StringName, _source: int, _target: int, _value: float) -> void:
	if not recording:
		return
	events[event] = int(events.get(event, 0)) + 1
	tag(("first:" if not seen_events.has(event) else "") + String(event))
	seen_events[event] = true


func emitter_entered(node: Node) -> void:
	if recording and not seen_emitters.has(node.get_instance_id()):
		seen_emitters[node.get_instance_id()] = true
		new_emitter_count += 1
		tag("new_emitter:" + String(node.get_meta("kind")))


func before_tick() -> void:
	if not recording:
		return
	tick_begin = Time.get_ticks_usec()
	seconds = float(Time.get_ticks_usec() - started) / 1000000.0
	# Benchmark fixture only: sustain combat for three minutes without a result/reload.
	for actor: Buffalo in [arena.player, arena.opponent]:
		if actor.spirit < GameBalance.get_number("spirit_max") * 0.5:
			actor.spirit = GameBalance.get_number("spirit_max")
		if actor.stamina < GameBalance.get_number("dash_cost"):
			actor.stamina = GameBalance.get_number("stamina_max")


func begin_frame() -> void:
	frame_begin = Time.get_ticks_usec()


func frame_for(slot: int) -> InputFrame:
	var actor := arena.player if slot == 1 else arena.opponent
	var other := arena.opponent if slot == 1 else arena.player
	var frame := InputFrame.new(slot)
	var toward := other.global_position - actor.global_position
	frame.camera_yaw = atan2(-toward.x, -toward.z)
	if toward.length() > GameBalance.get_number("clash_distance"):
		frame.move = Vector2(0.0, -1.0)
	if not arena.active_clash.is_empty():
		frame.move = Vector2(0.0, -1.0)
		frame.horn_pressed = not actor.clash_hooked and float(arena.active_clash.time) > GameBalance.get_number("lock_hook_startup_s")
		return frame
	var bucket := int(seconds / 1.6)
	var phase := int(seconds / 12.0) % 3
	if phase == 1 and slot == 1:
		frame.parry_pressed = other.state == Buffalo.State.HORN_STARTUP and other.state_time >= GameBalance.get_number("horn_startup_s") - GameBalance.get_number("parry_active_s") * 0.5
	elif phase == 2 and slot == 2:
		frame.guard_held = int(seconds) % 2 == 0
	elif last_horn[slot - 1] != bucket:
		frame.horn_pressed = true
		last_horn[slot - 1] = bucket
	if phase == 2 and slot == 1 and int(seconds / 2.0) != last_dash:
		last_dash = int(seconds / 2.0)
		frame.dash_pressed = true
		frame.horn_pressed = false
	return frame


func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		elif arg.begins_with("--seconds="):
			duration = arg.trim_prefix("--seconds=").to_float()
	low = label.ends_with("low")
	root.theme = load("res://assets/ui/festival_theme.tres")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GraphicsQuality.set_preset(GraphicsQuality.LOW if low else GraphicsQuality.HIGH)
	GraphicsQuality.set_fps_limit(GraphicsQuality.FPS_LIMITS.find(-1))
	SessionState.begin_free_play(&"L03")
	SessionState.auto_pause_enabled = false
	SessionState.replay_enabled = false
	change_scene_to_file("res://scenes/arena.tscn")
	await scene_changed
	arena = current_scene as MatchController
	arena.set_physics_process(false)
	var bot := BotInput.new()
	bot.fixture = self
	arena.local_input = bot
	arena.ai.queue_free()
	var opponent := BotAI.new()
	opponent.fixture = self
	arena.add_child(opponent)
	arena.ai = opponent
	arena.combat_event.connect(combat)
	arena.vfx.bursts.child_entered_tree.connect(emitter_entered)
	await create_timer(1.0).timeout
	arena.start_playing()
	arena.remaining_time = duration + 1.0
	physics_frame.connect(before_tick)
	process_frame.connect(begin_frame)
	audio = root.get_node("GameAudio") as FestivalAudio
	loaded_audio = audio.streams.duplicate()
	started = Time.get_ticks_usec()
	var previous := started
	var previous_writes: int = arena.hud.label_writes
	recording = true
	arena.set_physics_process(true)
	while float(Time.get_ticks_usec() - started) / 1000000.0 < duration:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if audio.streams.size() != loaded_audio.size():
			for cue in audio.streams:
				if not loaded_audio.has(cue):
					tag("audio_load:" + String(cue))
			loaded_audio = audio.streams.duplicate()
		var mask := 0
		for voice in audio.voices.size():
			if audio.voices[voice].playing:
				mask |= 1 << voice
		if mask & ~playing_mask:
			tag("audio_start")
		playing_mask = mask
		times.append(float(now - previous) / 1000.0)
		var work_begin := tick_begin if tick_begin > previous else frame_begin
		cpu.append(float(now - work_begin) / 1000.0)
		previous = now
		nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		emitters.append(arena.vfx.bursts.get_child_count())
		lights.append(arena.vfx.active_lights().size())
		writes.append(arena.hud.label_writes - previous_writes)
		previous_writes = arena.hud.label_writes
	recording = false
	physics_frame.disconnect(before_tick)
	process_frame.disconnect(begin_frame)
	var valid: bool = not arena.finished and times.size() > 0 and Array(times).min() > 0.0
	for event in [&"CLASH_START", &"DASH_START", &"HORN_HIT"]:
		valid = valid and events.get(event, 0) > 0
	write_results(valid)
	quit(0 if valid else 1)


func write_results(valid: bool) -> void:
	var base := "res://.scratch/orca/howto-lan-perf-2026-11-16/perf-" + label
	var csv := FileAccess.open(base + ".csv", FileAccess.WRITE)
	csv.store_line("frame,frame_ms,work_ms,nodes,emitters,lights,hud_writes,events")
	var indices: Array = range(times.size())
	indices.sort_custom(func(a: int, b: int): return times[a] > times[b])
	var total := 0.0
	for index in times.size():
		total += times[index]
		csv.store_line("%d,%.4f,%.4f,%d,%d,%d,%d,%s" % [index, times[index], cpu[index], nodes[index], emitters[index], lights[index], writes[index], "|".join(tags.get(index, PackedStringArray()))])
	var slow_count := maxi(1, ceili(times.size() * 0.01))
	var slow_total := 0.0
	for index in slow_count:
		slow_total += times[indices[index]]
	var worst: Array = []
	for rank in mini(20, indices.size()):
		var index: int = indices[rank]
		worst.append({"frame": index, "ms": times[index], "work_ms": cpu[index], "nodes": nodes[index], "emitters": emitters[index], "lights": lights[index], "hud_writes": writes[index], "events": tags.get(index, PackedStringArray())})
	var summary := {"label": label, "valid": valid, "seconds": total / 1000.0, "frames": times.size(), "avg_ms": total / times.size(), "avg_fps": times.size() * 1000.0 / total, "low_1pct_fps": slow_count * 1000.0 / slow_total, "max_ms": times[indices[0]], "new_emitters": new_emitter_count, "events": events, "worst20": worst}
	var json := FileAccess.open(base + ".json", FileAccess.WRITE)
	json.store_string(JSON.stringify(summary, "\t"))
	print("FRAME PACING ", JSON.stringify(summary))
