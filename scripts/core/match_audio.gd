extends Node
## Match sounds: countdown, announcer intro, crowd, and layered combat impacts.
## Combat sounds follow `combat_event`, which the host forwards to LAN clients, so
## both machines hear the same thing. Presentation only.

@onready var GameAudio := get_node("/root/GameAudio") as FestivalAudio
var controller: MatchController
var previous_phase: StringName = &""
var previous_count := -1
var previous_clash := false
var positions: Dictionary = {}
var step_times: Dictionary = {}
var struggle: AudioStreamPlayer
var intro_voice: AudioStreamPlayer
var intro_played := false
var crowd: AudioStreamPlayer
var pinned_before: Dictionary = {}
var pinned_cooldowns: Dictionary = {}
var guarded_hits: Dictionary = {}
var pending_impacts: Dictionary = {}
var recent_thumps: Dictionary = {}
var impact_variants: Dictionary = {}
var flee_before := false
var last_cheer_frame := -1


func _ready() -> void:
	controller = get_parent() as MatchController
	struggle = AudioStreamPlayer.new()
	struggle.bus = &"SFX"
	var loop := GameAudio.stream_for("buffalo_horn_lock_struggle_loop").duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	struggle.stream = loop
	var struggle_cue: Dictionary = GameAudio.settings.get("cues", {}).get("buffalo_horn_lock_struggle_loop", {})
	struggle.volume_db = float(struggle_cue.get("db", GameAudio.settings.get("struggle_db", -14.0)))
	add_child(struggle)
	crowd = AudioStreamPlayer.new()
	crowd.bus = &"SFX"
	var crowd_loop := GameAudio.stream_for("crowd_cheer").duplicate() as AudioStreamWAV
	crowd_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	crowd_loop.loop_begin = 0
	crowd_loop.loop_end = int(crowd_loop.get_length() * crowd_loop.mix_rate)
	crowd.stream = crowd_loop
	crowd.pitch_scale = float(GameAudio.settings.get("crowd_loop_pitch", 1.0))
	add_child(crowd)
	GameAudio.play_music("music_festival_loop", true)
	if controller.mode == &"LAN":
		intro_voice = GameAudio.play_sfx("announcer_intro_vi")
	controller.combat_event.connect(_combat_event)


func _process(delta: float) -> void:
	struggle.stream_paused = controller.paused
	crowd.stream_paused = controller.paused
	if is_instance_valid(intro_voice):
		if (not intro_voice.playing and not intro_voice.stream_paused) or intro_voice.stream != GameAudio.stream_for("announcer_intro_vi"):
			intro_voice = null
		else:
			intro_voice.stream_paused = controller.paused
			if controller.mode == &"SOLO" and not controller.announcer_active():
				intro_voice.stop()
				intro_voice.stream_paused = false
				intro_voice = null
	if controller.paused:
		return
	var ambience := controller.phase in [&"PLAYING", &"RESULT"]
	if ambience and not crowd.playing:
		crowd.play()
	elif not ambience:
		crowd.stop()
	var reaction := controller.get_node_or_null("CrowdReaction")
	var excitement := clampf(float(reaction.get("excitement")), 0.0, 1.0) if reaction != null else 0.0
	crowd.volume_db = lerpf(float(GameAudio.settings.get("crowd_loop_db", -30.0)), float(GameAudio.settings.get("crowd_loop_excited_db", -24.0)), excitement)
	var fleeing := controller.player.state == Buffalo.State.FLEE or controller.opponent.state == Buffalo.State.FLEE
	var flee_started := fleeing and not flee_before
	flee_before = fleeing
	var result_started := controller.phase == &"RESULT" and previous_phase != &"RESULT"
	if flee_started or result_started:
		_cheer()
	if controller.announcer_active() and not intro_played:
		intro_played = true
		intro_voice = GameAudio.play_sfx("announcer_intro_vi")
	if controller.phase != previous_phase:
		previous_phase = controller.phase
		if controller.phase == &"PLAYING":
			GameAudio.play_sfx("match_start_drums")
		elif controller.phase == &"RESULT":
			GameAudio.play_sfx("festival_gong")
			if controller.winner_slot == 0:
				GameAudio.play_sfx("ui_error")
			else:
				# GDD 2.5: the winner salutes the crowd to the festival drums.
				GameAudio.play_sfx("match_start_drums")
				GameAudio.play_music("music_victory" if controller.winner_slot == controller.local_slot else "music_defeat")
	if controller.phase == &"COUNTDOWN":
		var count := ceili(controller.countdown_time)
		if count > 0 and count != previous_count:
			previous_count = count
			GameAudio.play_sfx("countdown_drum")
	var locked := controller.clash.is_active() and not controller.finished
	if locked != previous_clash:
		previous_clash = locked
		if locked:
			GameAudio.play_sfx("buffalo_horn_lock_start")
			var cue: Dictionary = GameAudio.settings.get("cues", {}).get("buffalo_horn_lock_struggle_loop", {})
			var jitter := float(cue.get("pitch_jitter", 0.0))
			struggle.pitch_scale = float(cue.get("pitch", 1.0)) + GameAudio.pitch_rng.randf_range(-jitter, jitter)
			struggle.play()
		else:
			struggle.stop()
	for actor: Buffalo in [controller.player, controller.opponent]:
		var slot := actor.slot
		pinned_cooldowns[slot] = maxf(0.0, float(pinned_cooldowns.get(slot, 0.0)) - delta)
		var pinned := controller.phase == &"PLAYING" and controller.presentation_pinned(actor)
		if pinned and not bool(pinned_before.get(slot, false)) and pinned_cooldowns[slot] <= 0.0:
			GameAudio.play_sfx("wooden_fence_rattle")
			pinned_cooldowns[slot] = float(GameAudio.settings.get("pinned_rattle_cooldown_s", 1.0))
		pinned_before[slot] = pinned
		var last: Vector3 = positions.get(slot, actor.global_position)
		var distance := actor.global_position.distance_to(last)
		positions[slot] = actor.global_position
		step_times[slot] = maxf(0.0, float(step_times.get(slot, 0.0)) - delta)
		if controller.phase == &"PLAYING" and not locked and distance > 0.01 and distance < 1.0 and step_times[slot] <= 0.0:
			var mud := ArenaBounds.in_mud(actor.global_position, controller.mud_zones)
			GameAudio.play_sfx("buffalo_hoof_mud" if mud else "buffalo_hoof_dirt")
			step_times[slot] = float(GameAudio.settings.get("step_interval_s", 0.3))


func _exit_tree() -> void:
	if is_instance_valid(intro_voice) and intro_voice.stream == GameAudio.stream_for("announcer_intro_vi"):
		intro_voice.stop()
		intro_voice.stream_paused = false


func _combat_event(event: StringName, source: int, target: int, _value: float) -> void:
	var pair := Vector2i(source, target)
	if event in [&"HORN_START", &"COUNTER_START"]:
		GameAudio.play_sfx("sfx_horn_whoosh")
		GameAudio.play_sfx("buffalo_snort")
	elif event == &"DASH_START":
		GameAudio.play_sfx("sfx_dash_burst")
		GameAudio.play_sfx("sfx_dash_earth")
		GameAudio.play_sfx("buffalo_dash_steps")
	elif event == &"PARRY_SUCCESS":
		GameAudio.play_sfx("sfx_parry_ring")
		GameAudio.play_sfx("sfx_parry_impact")
	elif event == &"COUNTER_HIT":
		if pending_impacts.has(pair):
			pending_impacts[pair] = true
		elif recent_thumps.has(pair):
			var recent: Dictionary = recent_thumps[pair]
			var age := (Time.get_ticks_msec() - int(recent.time)) / 1000.0
			var voice: AudioStreamPlayer = recent.voice
			# Split LAN packets can deliver the modifier after playback has begun.
			if age < GameBalance.get_number("vfx_impact_merge_s") and is_instance_valid(voice) and voice.playing and voice.stream == GameAudio.stream_for("sfx_impact_thump"):
				var cue: Dictionary = GameAudio.settings.cues.sfx_impact_thump_heavy
				voice.volume_db = float(cue.db)
				voice.pitch_scale = float(cue.pitch) + GameAudio.pitch_rng.randf_range(-float(cue.pitch_jitter), float(cue.pitch_jitter))
		_cheer()
	elif event == &"GUARD_HIT":
		guarded_hits[pair] = Time.get_ticks_msec()
		recent_thumps.erase(pair)
		GameAudio.play_sfx("buffalo_block")
	elif event == &"CLASH_HOOK":
		GameAudio.play_sfx("clash_hook")
	if event not in [&"HORN_HIT", &"DASH_HIT"]:
		return
	# Resolver emits GUARD_HIT immediately before its HORN_HIT/DASH_HIT event.
	if guarded_hits.has(pair):
		var age := (Time.get_ticks_msec() - int(guarded_hits[pair])) / 1000.0
		guarded_hits.erase(pair)
		if age < GameBalance.get_number("vfx_impact_merge_s"):
			return
	# Resolver and LAN relay emit hit modifiers in order; wait until this batch ends.
	if not pending_impacts.has(pair):
		_play_impact.call_deferred(pair)
	pending_impacts[pair] = event == &"DASH_HIT"


func _play_impact(pair: Vector2i) -> void:
	var heavy: bool = pending_impacts[pair]
	pending_impacts.erase(pair)
	var cue := "sfx_heavy_impact_" if heavy else "sfx_horn_impact_"
	impact_variants[cue] = int(impact_variants.get(cue, 0)) % 2 + 1
	GameAudio.play_sfx(cue + str(impact_variants[cue]))
	if heavy:
		# The heavy wood sample lives below ~150 Hz, which laptop speakers barely play;
		# a lower, louder horn crack keeps the heavy hit stronger than a normal one there.
		GameAudio.play_sfx("sfx_heavy_crack_" + str(impact_variants[cue]))
	var thump := GameAudio.play_sfx("sfx_impact_thump_heavy" if heavy else "sfx_impact_thump")
	recent_thumps[pair] = {"time": Time.get_ticks_msec(), "voice": thump}


func _cheer() -> void:
	var frame := Engine.get_process_frames()
	if frame != last_cheer_frame:
		last_cheer_frame = frame
		GameAudio.play_sfx("crowd_cheer")
