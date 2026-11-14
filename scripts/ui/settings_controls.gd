class_name SettingsControls
extends RefCounted
## Builds the settings rows shared by the main menu and the in-match pause menu.


## Adds volume sliders, mouse sensitivity, fullscreen and camera-shake toggles to `container`.
## `on_sensitivity` is called with the new sensitivity after SessionState is updated.
static func populate(container: Container, on_sensitivity: Callable = Callable()) -> void:
	# The pause menu owns this legacy hint; keep its node available for other pause screens.
	if container.get_parent() != null:
		for sibling in container.get_parent().get_children():
			if sibling is Label and sibling.text == "Âm lượng áp dụng cho các bus audio của project.":
				sibling.text = "Cài đặt được lưu tự động."
	add_audio_slider(container, "Âm lượng tổng", "Master", "Âm thanh")
	add_audio_slider(container, "Nhạc", "Music")
	add_audio_slider(container, "Hiệu ứng", "SFX")
	var sensitivity := HSlider.new()
	sensitivity.max_value = 1.0
	sensitivity.step = GameBalance.get_number("ui_settings_sensitivity_slider_step")
	sensitivity.focus_mode = Control.FOCUS_ALL
	sensitivity.tooltip_text = "%d là mặc định; thang %d–%d." % [
		GameBalance.get_int("ui_settings_sensitivity_scale_default"),
		GameBalance.get_int("ui_settings_sensitivity_scale_min"),
		GameBalance.get_int("ui_settings_sensitivity_scale_max")
	]
	var current := SessionState.get_mouse_sensitivity()
	var baseline := GameBalance.get_number("mouse_sensitivity")
	var minimum := GameBalance.get_number("ui_settings_sensitivity_min")
	var maximum := GameBalance.get_number("ui_settings_sensitivity_max")
	# Each half gets equal travel so the saved default sits exactly at the midpoint.
	if current <= baseline:
		sensitivity.value = 0.5 * inverse_lerp(minimum, baseline, current)
	else:
		sensitivity.value = 0.5 + 0.5 * inverse_lerp(baseline, maximum, current)
	sensitivity.value_changed.connect(func(value: float):
		var actual := lerpf(minimum, baseline, value * 2.0) if value <= 0.5 else lerpf(baseline, maximum, (value - 0.5) * 2.0)
		SessionState.mouse_sensitivity = actual
		SessionState.save_settings()
		if on_sensitivity.is_valid():
			on_sensitivity.call(actual)
	)
	container.add_child(labeled("Độ nhạy chuột", sensitivity, "Điều khiển & hiển thị"))
	var fullscreen := CheckButton.new()
	style_toggle(fullscreen)
	fullscreen.text = "Toàn màn hình"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(set_fullscreen)
	container.add_child(fullscreen)
	var shake := CheckButton.new()
	style_toggle(shake)
	shake.text = "Rung camera"
	shake.button_pressed = SessionState.camera_shake_enabled
	shake.toggled.connect(func(enabled: bool):
		SessionState.camera_shake_enabled = enabled
		SessionState.save_settings()
	)
	container.add_child(shake)


static func style_toggle(button: CheckButton) -> void:
	var width := GameBalance.get_number("ui_settings_toggle_width")
	var height := GameBalance.get_number("ui_settings_toggle_height")
	var inset := GameBalance.get_number("ui_settings_toggle_inset")
	var border := GameBalance.get_number("ui_settings_toggle_border")
	for checked: bool in [false, true]:
		var fill := "#E8BC65" if checked else "#1C211F"
		var edge := "#E8BC65" if checked else "#C3AE89"
		var center := width - height * 0.5 if checked else height * 0.5
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s"><rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s" stroke="%s" stroke-width="%s"/><circle cx="%s" cy="%s" r="%s" fill="#F2E6CF"/></svg>' % [width, height, border * 0.5, border * 0.5, width - border, height - border, (height - border) * 0.5, fill, edge, border, center, height * 0.5, height * 0.5 - inset]
		var image := Image.new()
		if image.load_svg_from_string(svg) == OK:
			button.add_theme_icon_override("checked" if checked else "unchecked", ImageTexture.create_from_image(image))


## Adds a 0-100 linear volume slider bound to `bus_name`, creating the bus if needed.
static func add_audio_slider(container: Container, label_text: String, bus_name: StringName, group: String = "") -> void:
	var bus_index := FestivalAudio.ensure_bus(bus_name)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.focus_mode = Control.FOCUS_ALL
	slider.value = AudioServer.get_bus_volume_linear(bus_index) * 100.0
	slider.value_changed.connect(
		func(value: float):
			AudioServer.set_bus_volume_linear(bus_index, value / 100.0)
			SessionState.save_settings()
	)
	container.add_child(labeled(label_text, slider, group))


## A label stacked above `control`.
static func labeled(label_text: String, control: Control, group: String = "") -> VBoxContainer:
	var row := VBoxContainer.new()
	var heading := VBoxContainer.new()
	if not group.is_empty():
		var section := Label.new()
		section.text = group
		section.add_theme_font_size_override("font_size", GameBalance.get_int("ui_settings_group_font_size"))
		section.add_theme_color_override("font_color", Color("#E8BC65"))
		heading.add_child(section)
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var value := Label.new()
	value.name = "Value"
	value.add_theme_color_override("font_color", Color("#E8BC65"))
	line.add_child(value)
	var slider := control as HSlider
	var update := func(number: float):
		if slider.max_value == 100.0:
			value.text = "%d%%" % roundi(number)
		else:
			var baseline := GameBalance.get_number("ui_settings_sensitivity_scale_default")
			var display: float
			if number <= 0.5:
				display = lerpf(GameBalance.get_number("ui_settings_sensitivity_scale_min"), baseline, number * 2.0)
			else:
				display = lerpf(baseline, GameBalance.get_number("ui_settings_sensitivity_scale_max"), (number - 0.5) * 2.0)
			value.text = ("%.1f" % display).trim_suffix(".0")
	slider.value_changed.connect(update)
	update.call(slider.value)
	heading.add_child(line)
	row.add_child(heading)
	row.add_child(control)
	return row


static func set_fullscreen(enabled: bool) -> void:
	SessionState.fullscreen_enabled = enabled
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
	SessionState.save_settings()
