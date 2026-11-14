extends SceneTree

class AudioSpy extends FestivalAudio:
	var cues: Array[String] = []

	func play_sfx(cue: String) -> AudioStreamPlayer:
		cues.append(cue)
		return null

var failures := 0
var checks := 0
var spy := AudioSpy.new()
var match_audio := preload("res://scripts/core/match_audio.gd").new()


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func events(batch: Array, expected: Array, description: String) -> void:
	spy.cues.clear()
	for event in batch:
		match_audio._combat_event(event, 1, 2, 0.0)
	await process_frame
	await process_frame
	check(spy.cues == expected, description)


func run() -> void:
	var audio := root.get_node("GameAudio") as FestivalAudio
	spy.settings = audio.settings
	match_audio.GameAudio = spy
	await events([&"HORN_START"], ["sfx_horn_whoosh", "buffalo_snort"], "horn startup layers whoosh and snort")
	await events([&"COUNTER_START"], ["sfx_horn_whoosh", "buffalo_snort"], "counter startup layers whoosh and snort")
	await events([&"DASH_START"], ["sfx_dash_burst", "sfx_dash_earth", "buffalo_dash_steps"], "dash launch layers burst, CC0 earth and steps")
	await events([&"HORN_HIT"], ["sfx_horn_impact_1", "sfx_impact_thump"], "horn hit layers CC0 impact and bass")
	await events([&"HORN_HIT"], ["sfx_horn_impact_2", "sfx_impact_thump"], "successive horn hits rotate samples")
	await events([&"DASH_HIT"], ["sfx_heavy_impact_1", "sfx_heavy_crack_1", "sfx_impact_thump_heavy"], "dash hit selects heavy layers")
	await events([&"HORN_HIT", &"COUNTER_HIT", &"FLANK_HIT", &"BACK_HIT"], ["crowd_cheer", "sfx_heavy_impact_2", "sfx_heavy_crack_2", "sfx_impact_thump_heavy"], "counter upgrades base once despite flank/back modifiers")
	await events([&"DASH_HIT", &"COUNTER_HIT"], ["crowd_cheer", "sfx_heavy_impact_1", "sfx_heavy_crack_1", "sfx_impact_thump_heavy"], "counter dash plays exactly one heavy impact")
	await events([&"HORN_HIT", &"FLANK_HIT", &"BACK_HIT"], ["sfx_horn_impact_1", "sfx_impact_thump"], "flank/back preserve one normal impact")
	await events([&"GUARD_HIT", &"HORN_HIT", &"COUNTER_HIT"], ["buffalo_block", "crowd_cheer"], "guard suppresses base and counter impact layers")
	await events([&"GUARD_HIT", &"DASH_HIT"], ["buffalo_block"], "guard suppresses heavy dash impact")
	await events([&"PARRY_SUCCESS"], ["sfx_parry_ring", "sfx_parry_impact"], "parry uses ring and dry CC0 without old pair")
	# A guard notification cannot swallow an unrelated later hit or the opposite pair.
	match_audio._combat_event(&"GUARD_HIT", 1, 2, 0.0)
	match_audio.guarded_hits[Vector2i(1, 2)] -= int(GameBalance.get_number("vfx_impact_merge_s") * 1000) + 1
	await events([&"HORN_HIT"], ["sfx_horn_impact_2", "sfx_impact_thump"], "expired guard does not swallow a later hit")
	match_audio._combat_event(&"GUARD_HIT", 2, 1, 0.0)
	await events([&"HORN_HIT"], ["sfx_horn_impact_1", "sfx_impact_thump"], "guard suppression belongs to attacker/target pair")
	match_audio.guarded_hits.clear()
	spy.cues.clear()
	match_audio._combat_event(&"HORN_HIT", 1, 2, 0.0)
	match_audio._combat_event(&"DASH_HIT", 2, 1, 0.0)
	await process_frame
	await process_frame
	check(spy.cues == ["sfx_horn_impact_2", "sfx_impact_thump", "sfx_heavy_impact_2", "sfx_heavy_crack_2", "sfx_impact_thump_heavy"], "simultaneous opposite hits retain both impacts")
	for cue in ["sfx_horn_whoosh", "sfx_impact_thump", "sfx_impact_thump_heavy", "sfx_parry_ring", "sfx_dash_burst", "sfx_horn_impact_1", "sfx_horn_impact_2", "sfx_heavy_impact_1", "sfx_heavy_impact_2", "sfx_heavy_crack_1", "sfx_heavy_crack_2", "sfx_parry_impact", "sfx_dash_earth"]:
		var tuning: Dictionary = audio.settings.cues.get(cue, {})
		var voice := audio.play_sfx(cue)
		var valid := voice != null and not tuning.is_empty()
		if valid:
			var path := "res://assets/audio/" + str(tuning.get("stream", cue)) + ".wav"
			valid = FileAccess.file_exists(path) and voice.stream == audio.stream_for(cue) and is_equal_approx(voice.volume_db, float(tuning.db)) and absf(voice.pitch_scale - float(tuning.pitch)) <= float(tuning.pitch_jitter) + 0.00001
			voice.stop()
		check(valid, "new cue has asset and applies configured gain/pitch: " + cue)
	var heavy: Dictionary = audio.settings.cues.sfx_impact_thump_heavy
	var normal: Dictionary = audio.settings.cues.sfx_impact_thump
	check(heavy.db > normal.db and heavy.pitch < normal.pitch and heavy.stream == "sfx_impact_thump", "heavy bass reuses thump with louder gain and lower pitch")
	check(audio.voices.size() == 32, "32 voices reserve room for layered events")
	for voice in audio.voices:
		voice.stop()
	var retained := true
	for i in 24:
		retained = audio.play_sfx("sfx_horn_whoosh") != null and retained
	for cue in ["sfx_heavy_impact_1", "sfx_heavy_crack_1", "sfx_impact_thump_heavy", "sfx_dash_burst", "sfx_dash_earth", "buffalo_dash_steps", "announcer_intro_vi"]:
		retained = audio.play_sfx(cue) != null and retained
	check(retained, "layered impact, dash and announcer survive 24 occupied voices")
	for voice in audio.voices:
		voice.stop()
	match_audio.GameAudio = audio
	match_audio._combat_event(&"HORN_HIT", 1, 2, 0.0)
	await process_frame
	await process_frame
	var contact: Dictionary = match_audio.recent_thumps[Vector2i(1, 2)]
	var thump: AudioStreamPlayer = contact.voice
	match_audio._combat_event(&"COUNTER_HIT", 1, 2, 0.0)
	var thumps := 0
	for voice in audio.voices:
		if voice.playing and voice.stream == audio.stream_for("sfx_impact_thump"):
			thumps += 1
	check(thumps == 1 and is_equal_approx(thump.volume_db, float(heavy.db)) and absf(thump.pitch_scale - float(heavy.pitch)) <= float(heavy.pitch_jitter) + 0.00001, "split LAN counter upgrades the playing bass without another impact")
	contact.time -= int(GameBalance.get_number("vfx_impact_merge_s") * 1000) + 1
	thump.volume_db = float(normal.db)
	match_audio._combat_event(&"COUNTER_HIT", 1, 2, 0.0)
	check(is_equal_approx(thump.volume_db, float(normal.db)) and thump.playing, "late modifier outside merge window leaves the earlier impact alone")
	for voice in audio.voices:
		voice.stop()
	match_audio.free()
	spy.free()
	print("%d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
