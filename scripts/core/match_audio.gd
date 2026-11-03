extends Node
## Audio observer: state transitions also work on LAN clients receiving snapshots.

@onready var GameAudio := get_node("/root/GameAudio") as FestivalAudio
var controller: MatchController
var previous_phase: StringName = &""
var previous_count := -1
var previous_clash := false
var states: Dictionary = {}
var spirits: Dictionary = {}
var positions: Dictionary = {}
var step_times: Dictionary = {}
var struggle: AudioStreamPlayer


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
	GameAudio.play_sfx("announcer_intro_vi")
	controller.combat_event.connect(_combat_event)


func _process(delta: float) -> void:
	struggle.stream_paused = controller.paused
	if controller.paused:
		return
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
		var old_state: int = states.get(slot, actor.state)
		if old_state != actor.state:
			if actor.state == Buffalo.State.HORN_STARTUP:
				GameAudio.play_sfx("buffalo_snort")
			elif actor.state == Buffalo.State.DASH_ACTIVE:
				GameAudio.play_sfx("buffalo_dash_steps")
		# Snapshot-only clients have no combat_event signal; resource drops are the fallback.
		if controller.lan != null and controller.lan.is_client() and actor.spirit < float(spirits.get(slot, actor.spirit)):
			GameAudio.play_sfx("buffalo_block" if actor.guarding else "buffalo_horn_hit")
		spirits[slot] = actor.spirit
		states[slot] = actor.state
		var last: Vector3 = positions.get(slot, actor.global_position)
		var distance := actor.global_position.distance_to(last)
		positions[slot] = actor.global_position
		step_times[slot] = maxf(0.0, float(step_times.get(slot, 0.0)) - delta)
		if controller.phase == &"PLAYING" and not locked and distance > 0.01 and distance < 1.0 and step_times[slot] <= 0.0:
			var mud := ArenaBounds.in_mud(actor.global_position, controller.mud_zones)
			GameAudio.play_sfx("buffalo_hoof_mud" if mud else "buffalo_hoof_dirt")
			step_times[slot] = float(GameAudio.settings.get("step_interval_s", 0.3))


func _combat_event(event: StringName, _source: int, target: int, _value: float) -> void:
	if event not in [&"HORN_HIT", &"DASH_HIT"]:
		return
	var actor := controller.player if target == 1 else controller.opponent
	GameAudio.play_sfx("buffalo_block" if actor.guarding else "buffalo_horn_hit")
	if ArenaBounds.is_pinned(actor, actor.global_position.normalized()):
		GameAudio.play_sfx("wooden_fence_rattle")
