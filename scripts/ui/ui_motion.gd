class_name UiMotion
extends RefCounted
## Presentation-only motion shared by menus and HUD; never delays a scene change.


## Adds mouse, keyboard and gamepad feedback without changing layout or focus rules.
static func attach(button: BaseButton) -> void:
	if button.has_meta("ui_motion"):
		return
	var state := {"hovered": false, "focused": false, "down": false, "tween": null}
	button.set_meta("ui_motion", state)
	var center := func(): button.pivot_offset = button.size * 0.5
	button.resized.connect(center)
	center.call()
	var update := func(key: String, active: bool):
		state[key] = active
		if state.tween != null:
			state.tween.kill()
		var target := 1.0
		if not button.disabled:
			if state.down:
				target = GameBalance.get_number("ui_motion_press_scale")
			elif state.hovered or state.focused:
				target = GameBalance.get_number("ui_motion_hover_scale")
		state.tween = button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		state.tween.tween_property(button, "scale", Vector2.ONE * target, GameBalance.get_number("ui_motion_button_s")).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.mouse_entered.connect(update.bind("hovered", true))
	button.mouse_exited.connect(update.bind("hovered", false))
	button.focus_entered.connect(update.bind("focused", true))
	button.focus_exited.connect(update.bind("focused", false))
	button.button_down.connect(update.bind("down", true))
	button.button_up.connect(update.bind("down", false))
	button.visibility_changed.connect(func():
		if not button.is_visible_in_tree():
			state.hovered = false
			state.focused = false
			state.down = false
			if state.tween != null:
				state.tween.kill()
			button.scale = Vector2.ONE
	)


## Samples an ease-out pop with the HUD's own elapsed time, including its pause rules.
static func banner_scale(elapsed: float) -> Vector2:
	var duration := GameBalance.get_number("ui_banner_pop_s")
	var start := GameBalance.get_number("ui_banner_pop_scale")
	return Vector2.ONE * Tween.interpolate_value(start, 1.0 - start, clampf(elapsed, 0.0, duration), duration, Tween.TRANS_QUAD, Tween.EASE_OUT)


## Slides the result in from the left; button opacity staggers independently of focus scale.
static func enter_result(panel: Control, actions: Container) -> Tween:
	var tween := panel.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var duration := GameBalance.get_number("ui_motion_result_s")
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, duration)
	var destination := panel.position.x
	panel.position.x -= GameBalance.get_number("ui_motion_result_slide_px")
	tween.tween_property(panel, "position:x", destination, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for button: Control in actions.get_children():
		button.modulate.a = 0.0
		var delay := GameBalance.get_number("ui_motion_result_button_delay_s") + button.get_index() * GameBalance.get_number("ui_motion_result_stagger_s")
		tween.tween_property(button, "modulate:a", 1.0, GameBalance.get_number("ui_motion_result_button_s")).set_delay(delay)
	return tween


## Changes scene immediately under a captured outgoing frame, fading through festival dark.
## The root owns the overlay so it survives freed menus, pause screens and Solo results.
static func change_scene(tree: SceneTree, scene: PackedScene) -> Error:
	var overlay: CanvasLayer
	if DisplayServer.get_name() != "headless":
		var previous := tree.root.get_node_or_null("UiSceneFade")
		if previous != null:
			previous.free()
		overlay = CanvasLayer.new()
		overlay.name = "UiSceneFade"
		overlay.layer = GameBalance.get_int("ui_fade_layer")
		overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(overlay)
		var frame := TextureRect.new()
		frame.texture = ImageTexture.create_from_image(tree.root.get_texture().get_image())
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(frame)
		var dark := ColorRect.new()
		dark.name = "Dark"
		dark.color = Color("#1E1914")
		dark.modulate.a = 0.0
		dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(dark)
		var tween := overlay.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(dark, "modulate:a", 1.0, GameBalance.get_number("ui_fade_out_s"))
		tween.tween_callback(frame.queue_free)
		tween.tween_property(dark, "modulate:a", 0.0, GameBalance.get_number("ui_fade_in_s"))
		tween.tween_callback(overlay.queue_free)
	var error := tree.change_scene_to_packed(scene)
	if error != OK and overlay != null:
		overlay.queue_free()
	return error
