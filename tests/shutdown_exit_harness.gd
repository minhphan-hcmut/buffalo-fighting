extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var frames := int(OS.get_cmdline_user_args()[0])
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	for frame in frames:
		await process_frame
	var audio: Node
	for node in arena.get_children():
		if node.get_script() == load("res://scripts/core/match_audio.gd"):
			audio = node
	audio._combat_event(&"HORN_HIT", 1, 2, 1.0)
	root.remove_child(arena)
	var clean: bool = audio.struggle.stream == null and audio.crowd.stream == null and audio.intro_voice == null
	if not clean:
		push_error("Match audio retained streams after leaving tree")
	await process_frame
	arena.free()
	await create_timer(0.05).timeout
	quit(0 if clean else 1)
