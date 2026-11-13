extends Node
## Match sounds: countdown, announcer intro, crowd, and one sound per combat event.
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


func _ready() -> void:
	controller = get_parent() as MatchController
	struggle = AudioStreamPlayer.new()
	struggle.bus = &"SFX"
	var loop := GameAudio.stream_for("buffalo_horn_lock_struggle_loop").duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	struggle.stream = loop
	struggle.volume_db = float(GameAudio.settings.get("struggle_db", -14.0))
	add_child(struggle)
	GameAudio.play_music("music_festival_loop", true)
	if controller.mode == &"LAN":
		GameAudio.play_sfx("announcer_intro_vi")
	controller.combat_event.connect(_combat_event)


func _process(delta: float) -> void:
	struggle.stream_paused = controller.paused
	if is_instance_valid(intro_voice):
		if (not intro_voice.playing and not intro_voice.stream_paused) or intro_voice.stream != GameAudio.stream_for("announcer_intro_vi"):
			intro_voice = null
		else:
			intro_voice.stream_paused = controller.paused
			if not controller.announcer_active():
				intro_voice.stop()
				intro_voice.stream_paused = false
				intro_voice = null
	if controller.paused:
		return
	if controller.announcer_active() and not intro_played:
		intro_played = true
		intro_voice = GameAudio.play_sfx("announcer_intro_vi")
	if controller.phase != previous_phase:
		previous_phase = controller.phase
		if controller.phase == &"PLAYING":
			GameAudio.play_sfx("match_start_drums")
		elif controller.phase == &"RESULT":
			GameAudio.play_sfx("festival_gong")
			GameAudio.play_sfx("crowd_cheer")
			if controller.winner_slot == 0:
				GameAudio.play_sfx("ui_error")
			else:
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
			struggle.play()
		else:
			struggle.stop()
	for actor: Buffalo in [controller.player, controller.opponent]:
		var slot := actor.slot
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


func _combat_event(event: StringName, _source: int, target: int, _value: float) -> void:
	if event in [&"HORN_START", &"COUNTER_START"]:
		GameAudio.play_sfx("buffalo_snort")
	elif event == &"DASH_START":
		GameAudio.play_sfx("buffalo_dash_steps")
	elif event == &"PARRY_SUCCESS":
		GameAudio.play_sfx("buffalo_block")
		GameAudio.play_sfx("buffalo_horn_hit")
	elif event == &"COUNTER_HIT":
		GameAudio.play_sfx("crowd_cheer")
	if event not in [&"HORN_HIT", &"DASH_HIT"]:
		return
	var actor := controller.player if target == 1 else controller.opponent
	GameAudio.play_sfx("buffalo_block" if actor.guarding else "buffalo_horn_hit")
	if ArenaBounds.is_pinned(actor, actor.global_position.normalized()):
		GameAudio.play_sfx("wooden_fence_rattle")
