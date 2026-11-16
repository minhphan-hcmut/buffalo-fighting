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


func settle() -> void:
	await create_timer(GameBalance.get_number("ui_motion_button_s") + 0.05).timeout


func run() -> void:
	var data := DataFile.load_json("res://data/presentation.json")
	for key in [
		"ui_motion_hover_scale", "ui_motion_press_scale", "ui_motion_button_s",
		"ui_motion_result_s", "ui_motion_result_slide_px", "ui_motion_result_button_s",
		"ui_motion_result_button_delay_s", "ui_motion_result_stagger_s",
		"ui_fade_out_s", "ui_fade_in_s", "ui_fade_layer",
		"ui_banner_pop_scale", "ui_banner_pop_s", "ui_banner_outline_size",
		"ui_banner_shadow_alpha", "ui_banner_shadow_offset_y"
	]:
		check(data.has(key) and GameBalance.get_number(key) > 0.0, "presentation contains positive tuning: " + key)
	check(GameBalance.get_number("ui_fade_out_s") + GameBalance.get_number("ui_fade_in_s") <= 0.35, "full scene fade fits the 0.35 s budget")
	var button := Button.new()
	button.custom_minimum_size = Vector2(360, 54)
	UiMotion.attach(button)
	UiMotion.attach(button)
	root.add_child(button)
	await process_frame
	button.release_focus()
	button.mouse_exited.emit()
	await settle()
	var original_size := button.size
	var minimum := button.custom_minimum_size
	check(button.pivot_offset == button.size * 0.5, "button pivot starts centred")
	button.size += Vector2(40, 10)
	check(button.pivot_offset == button.size * 0.5, "button pivot follows resize")
	button.size = original_size
	button.mouse_entered.emit()
	await settle()
	check(is_equal_approx(button.scale.x, GameBalance.get_number("ui_motion_hover_scale")), "hover scales the button up")
	button.button_down.emit()
	await settle()
	check(is_equal_approx(button.scale.x, GameBalance.get_number("ui_motion_press_scale")), "press dips the button")
	button.button_up.emit()
	await settle()
	check(button.scale.x > 1.0, "release restores hover feedback")
	button.mouse_exited.emit()
	await settle()
	check(button.scale.is_equal_approx(Vector2.ONE), "leaving hover returns to one")
	button.grab_focus()
	await settle()
	check(button.has_focus() and button.scale.x > 1.0, "keyboard/gamepad focus scales up")
	button.mouse_entered.emit()
	button.mouse_exited.emit()
	await settle()
	check(button.scale.x > 1.0, "mouse exit preserves focused feedback")
	button.button_down.emit()
	await settle()
	check(button.scale.x < 1.0, "focused press dips too")
	button.button_up.emit()
	button.release_focus()
	await settle()
	check(button.scale.is_equal_approx(Vector2.ONE), "focus release returns to one")
	button.mouse_entered.emit()
	button.button_down.emit()
	button.button_up.emit()
	button.mouse_exited.emit()
	await settle()
	check(button.scale.is_equal_approx(Vector2.ONE), "rapid input cancels previous tweens")
	button.disabled = true
	button.mouse_entered.emit()
	await settle()
	check(button.scale.is_equal_approx(Vector2.ONE), "disabled button does not animate up")
	button.disabled = false
	button.mouse_exited.emit()
	paused = true
	button.focus_entered.emit()
	await settle()
	check(button.scale.x > 1.0, "feedback still runs while match is paused")
	paused = false
	button.hide()
	check(button.scale.is_equal_approx(Vector2.ONE), "hidden button resets its scale")
	check(button.size == original_size and button.custom_minimum_size == minimum, "motion preserves size and custom minimum size")
	button.free()

	check(UiMotion.banner_scale(0.0).x > 1.0, "banner pop starts larger than one")
	var halfway := UiMotion.banner_scale(GameBalance.get_number("ui_banner_pop_s") * 0.5).x
	check(halfway > 1.0 and halfway < UiMotion.banner_scale(0.0).x, "banner pop eases toward rest")
	check(UiMotion.banner_scale(GameBalance.get_number("ui_banner_pop_s")) == Vector2.ONE, "banner pop settles at one")
	check(UiMotion.banner_scale(10.0) == Vector2.ONE, "banner remains at rest after pop")
	await _check_result()
	print("UI MOTION TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _check_result() -> void:
	var panel := Control.new()
	panel.position = Vector2(64, 100)
	root.add_child(panel)
	var actions := VBoxContainer.new()
	panel.add_child(actions)
	for i in 3:
		actions.add_child(Button.new())
	var destination := panel.position
	var tween := UiMotion.enter_result(panel, actions)
	tween.pause()
	check(panel.modulate.a == 0.0, "result entrance starts transparent")
	tween.custom_step(0.001)
	check(panel.position.x < destination.x, "result entrance starts left of its destination")
	tween.custom_step(GameBalance.get_number("ui_motion_result_button_delay_s") + GameBalance.get_number("ui_motion_result_stagger_s"))
	check(actions.get_child(0).modulate.a > actions.get_child(2).modulate.a, "result buttons enter in a light stagger")
	tween.custom_step(1.0)
	check(panel.position.is_equal_approx(destination) and is_equal_approx(panel.modulate.a, 1.0), "result entrance settles at its original layout")
	check(is_equal_approx(actions.get_child(2).modulate.a, 1.0), "last result button becomes fully visible")
	panel.free()
