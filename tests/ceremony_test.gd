extends SceneTree
## Phần Lễ screens (GDD Bảng 17): opening and closing tableaux, captions from data,
## auto-advance within the 15 s cap, skip after the minimum view time, single finish.

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
	var data := DataFile.load_json(CeremonyView.DATA_PATH)
	check(float(data.get("duration_s", 99.0)) <= 15.0, "ceremony duration respects the GDD 15 s cap")
	for which in [&"opening", &"closing"]:
		var scene: Dictionary = data.get(String(which), {})
		check(not String(scene.get("title", "")).is_empty() and (scene.get("lines", []) as Array).size() in [1, 2], "%s has a title and one or two caption lines" % which)
		await _check_view(which, scene, data)
	_check_wording(data)
	print("CEREMONY TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _check_view(which: StringName, scene: Dictionary, data: Dictionary) -> void:
	var view := CeremonyView.create(which)
	var finish_count := [0]
	view.finished.connect(func(): finish_count[0] += 1)
	root.add_child(view)
	await process_frame
	var diorama := view.diorama
	check(diorama != null and diorama.get_node_or_null("Shrine") != null, "%s builds the shrine tableau" % which)
	check(diorama.camera != null and diorama.camera.is_inside_tree(), "%s has a camera in its own world" % which)
	check(view.caption_label.text == "\n".join(PackedStringArray(scene.get("lines", []))), "%s caption comes from data/ceremony.json" % which)
	check(view.continue_button.text == String(scene.get("button", "")), "%s continue button text comes from data" % which)
	if which == &"opening":
		check(diorama.flag != null and not diorama.flag_raised(), "opening flag starts low on the pole")
		view.advance(float(data.get("flag_rise_s", 5.0)) + 0.1)
		check(diorama.flag_raised(), "opening flag reaches the top after flag_rise_s")
	else:
		check(diorama.champion != null and diorama.leader != null, "closing shows the champion buffalo and its leader")
		var start_z := diorama.champion.position.z
		view.advance(float(data.get("procession_s", 12.0)) * 0.5)
		check(diorama.champion.position.z < start_z, "closing procession moves toward the shrine")
	check(finish_count[0] == 0, "%s keeps running before duration_s" % which)
	view.advance(float(data.get("duration_s", 15.0)))
	check(finish_count[0] == 1 and view.done, "%s finishes on its own by duration_s" % which)
	view.finish()
	check(finish_count[0] == 1, "%s emits finished only once" % which)
	view.queue_free()
	await process_frame

	var early := CeremonyView.create(which)
	var early_count := [0]
	early.finished.connect(func(): early_count[0] += 1)
	root.add_child(early)
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	early.elapsed = 0.0
	early._input(key)
	check(early_count[0] == 0, "%s ignores a key pressed before min_view_s" % which)
	early.elapsed = float(data.get("min_view_s", 0.6)) + 0.01
	early._input(key)
	check(early_count[0] == 1, "%s skips on a key after min_view_s" % which)
	early.queue_free()
	await process_frame


func _check_wording(data: Dictionary) -> void:
	# GDD 4.6: no violent wording, fictional village (no real place names outside culture cards).
	var text := JSON.stringify(data).to_lower()
	for banned in ["hạ gục", "tiêu diệt", "đo ván", "máu", "giết", "đồ sơn"]:
		check(not text.contains(banned), "ceremony text avoids '%s'" % banned)
