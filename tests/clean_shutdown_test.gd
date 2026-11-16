extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func run() -> void:
	# Capture child stderr through process exit: a coroutine warning may occur after quit().
	for frames in [0, 1, 3]:
		var output: Array = []
		var status := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/shutdown_exit_harness.gd", "--", str(frames)], output, true)
		var log := "\n".join(output)
		check(status == 0, "match audio releases owned streams at teardown frame %d" % frames)
		check(not log.contains("Resumed function 'warm_up()'"), "warm-up cannot resume after teardown frame %d" % frames)
		check(not log.contains("SCRIPT ERROR"), "deferred audio cannot access cleared state after teardown frame %d" % frames)
		if status != 0 or log.contains("Resumed function 'warm_up()'"):
			print(log)
	var audio := FestivalAudio.new()
	root.add_child(audio)
	audio.play_sfx("ui_confirm")
	root.remove_child(audio)
	check(audio.streams.is_empty() and audio.voices.is_empty(), "audio autoload releases its stream cache and voice references on exit")
	for player in audio.get_children():
		if player is AudioStreamPlayer:
			check(player.stream == null and not player.playing, "audio player stops and releases playback stream")
	audio.free()
	await process_frame
	print("CLEAN SHUTDOWN FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
