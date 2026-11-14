extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func text_of(node: Node) -> String:
	var text := ""
	if node is Label or node is Button:
		text = node.text + "\n"
	elif node is RichTextLabel:
		text = node.get_parsed_text() + "\n"
	for child in node.get_children():
		text += text_of(child)
	return text


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


# Sample actual upper-body vertices, independent of the demo's contact anchors.
func mesh_contact_gap(attacker: Buffalo, victim: Buffalo, flank: bool) -> float:
	var from := upper_body_points(attacker, true)
	var to := upper_body_points(victim, not flank)
	var closest := INF
	for a in from:
		for b in to:
			closest = minf(closest, a.distance_squared_to(b))
	return sqrt(closest)


func upper_body_points(actor: Buffalo, head_only: bool) -> PackedVector3Array:
	var mesh := actor.visual.find_child("HeroBody", true, false) as MeshInstance3D
	var points := PackedVector3Array()
	for surface in mesh.mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for index in range(0, vertices.size(), 8):
			var point := vertices[index]
			if point.y < 1.0 or (head_only and point.z > -0.6):
				continue
			points.append(mesh.to_global(point))
	return points


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	var howto := HowToPlay.new()
	root.add_child(howto)
	for i in 4:
		await process_frame
	check(howto.tabs.size() == 3 and howto.tabs.map(func(tab: Button): return tab.text) == ["LUẬT CHƠI", "CÁC ĐÒN", "ĐIỀU KHIỂN"], "three named festival tabs exist")
	check(howto.demo == null, "demo scene is lazy on Rules")
	check(root.get_visible_rect().encloses(howto.panel.get_global_rect()), "panel fits 1280 × 720")
	var rules := text_of(howto.pages[0])
	for keyword in ["MỤC TIÊU", "GIỮ SỨC", "MẸO TRÊN SỚI", "KHÍ THẾ", "SỨC", "sườn", "lưng", "sát rào", "Gạt sừng", "bốc thăm", "%d giây" % GameBalance.get_int("match_duration_s")]:
		check(rules.contains(keyword), "Rules preserves " + keyword)
	for block in howto.pages[0].get_children():
		check((block.get_child(1) as RichTextLabel).text.contains("[b][color=#E8BC65]"), "Rules highlights keywords in bold gold")
	howto.tabs[0].grab_focus()
	await key(KEY_RIGHT)
	check(howto.selected_tab == 1 and howto.tabs[1].has_focus(), "Right selects and focuses Moves")
	var demo := howto.demo
	check(demo != null and demo.move_buttons.size() == 6, "all six moves share a lazy demo")
	demo.set_physics_process(false)
	demo.sample_time(1.05)
	check(demo.red.state == Buffalo.State.HORN_ACTIVE and demo.blue.state == Buffalo.State.STUNNED and demo.blue.position.x > GameBalance.get_number("demo_contact_half_gap"), "Horn at about one second attacks and pushes/stuns blue")
	check(demo.red.slot == 1 and demo.blue.slot == 2 and demo.blue.find_child("FACTION_Cloth_and_Belt", true, false) != null, "real buffalo scenes retain the red and blue dress")
	var viewport := demo.viewport
	for index in 6:
		demo.move_buttons[index].pressed.emit()
		demo.set_physics_process(false)
		demo.sample_time(1.05)
		check(demo.selected_move == MoveDemo.MOVES[index].id and demo.viewport == viewport, "selecting %s resets its timeline in the same viewport" % MoveDemo.MOVES[index].name)
		match MoveDemo.MOVES[index].id:
			&"dash":
				check(demo.red.state == Buffalo.State.DASH_ACTIVE, "Dash timeline changes the red action")
			&"guard":
				check(demo.red.state == Buffalo.State.GUARD and demo.blue.state == Buffalo.State.HORN_ACTIVE, "Guard shows a blocked horn without stun")
			&"parry":
				demo.sample_time(1.5)
				check(demo.red.state == Buffalo.State.HORN_ACTIVE and demo.blue.state == Buffalo.State.STUNNED and demo.callout.text == "PHẢN ĐÒN!", "Parry leads into a counter horn")
			&"clash":
				check(demo.red.state == Buffalo.State.CLASH and demo.blue.state == Buffalo.State.CLASH, "Clash shows both locked horns")
			&"flank":
				check(demo.blue.facing == Vector3.FORWARD and demo.red.facing.dot(demo.blue.facing) < 0.1, "Flank faces the side of the opponent")
	check(MoveDemo.MOVES.map(func(move: Dictionary): return move.id) == [&"horn", &"dash", &"guard", &"parry", &"clash", &"flank"], "move definitions have explicit stable ids")
	var camera := demo.world.get_viewport().get_camera_3d()
	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "stage uses perspective")
	var sun := demo.world.get_node("Sun") as DirectionalLight3D
	check(is_equal_approx(sun.light_energy, GameBalance.get_number("ui_sun_energy")), "stage uses arena lighting")
	for actor in [demo.red, demo.blue]:
		var mesh := actor.visual.find_child("HeroBody", true, false) as MeshInstance3D
		check(mesh.get_active_material(0).next_pass is ShaderMaterial, "buffalo retains its team outline")
	for move in MoveDemo.MOVES:
		demo.select_move(move.id)
		demo.set_physics_process(false)
		demo.sample_time(1.5 if move.id == &"parry" else 1.05)
		for i in 30:
			for actor in [demo.red, demo.blue]:
				(actor.visual as BuffaloAnimator).update_pose(1.0 / 60.0)
			demo._process(0.0)
		var attacker := demo.blue if move.id == &"guard" else demo.red
		var victim := demo.red if move.id == &"guard" else demo.blue
		var gap := mesh_contact_gap(attacker, victim, move.id == &"flank")
		check(gap < 0.15, "%s actual forehead/horn-to-body gap is below 0.15 m (%.3f m)" % [move.name, gap])
		check(demo.impact.visible and demo.impact.position.distance_to(demo.callout.position - Vector3.UP * GameBalance.get_number("demo_callout_height")) < 0.01, "impact sparks and callout follow the contact point: " + move.name)
	demo.move_buttons[0].grab_focus()
	await key(KEY_DOWN)
	check(demo.selected_move == &"dash" and demo.move_buttons[1].has_focus(), "Down selects the next move")
	await key(KEY_UP)
	check(demo.selected_move == &"horn", "Up selects the preceding move")
	await key(KEY_RIGHT)
	check(howto.selected_tab == 2 and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not demo.is_physics_processing() and demo.world.process_mode == Node.PROCESS_MODE_DISABLED, "hidden Moves stops rendering, timeline and animator")
	var controls := howto.pages[2]
	var controls_text := text_of(controls)
	for binding in ["W", "A", "S", "D", "Space", "G", "Esc", "Húc", "Ghìm (giữ)", "Di chuột:", "nhìn quanh", "Đẩy", "Móc", "Nhả"]:
		check(controls_text.contains(binding), "Controls includes " + binding)
	check(text_of(controls.find_child("MouseLeft", true, false)) == "Chuột trái\nHúc\n" and text_of(controls.find_child("MouseRight", true, false)) == "Chuột phải\nGhìm (giữ)\n", "mouse buttons have their correct separate labels")
	var caps := controls.find_children("*", "PanelContainer", true, false)
	var used_caps := 0
	var key_positions: Dictionary = {}
	for cap in caps:
		if cap.get_child(0) is Label:
			var label := cap.get_child(0) as Label
			key_positions[label.text] = cap.global_position
			if (cap.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == ControlsDiagram.GOLD:
				used_caps += 1
			check(howto.panel.get_global_rect().encloses(cap.get_global_rect()), "visible keycap fits panel: " + label.text)
	check(used_caps >= 12, "used keys use gold fill")
	check(key_positions.W.y < key_positions.S.y and is_equal_approx(key_positions.W.x, key_positions.S.x) and key_positions.A.x < key_positions.S.x and key_positions.D.x > key_positions.S.x, "WASD preserves keyboard geometry")
	howto.tabs[0].grab_focus()
	await key(KEY_TAB)
	check(howto.selected_tab == 1 and howto.tabs[1].has_focus(), "Tab reaches and selects the next tab")
	check(viewport.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE, "returning to Moves resumes rendering")
	var closed := [false]
	howto.closed.connect(func(): closed[0] = true)
	var demo_ref: WeakRef = weakref(demo)
	await key(KEY_ESCAPE)
	check(closed[0] and demo_ref.get_ref() == null, "Esc emits close and frees the demo")
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await physics_frame
	await physics_frame
	print("HOW TO PLAY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
