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
	_camera_row(container)
	var comfort := Button.new()
	comfort.name = "ComfortButton"
	comfort.text = "Hiệu ứng  ›"
	comfort.focus_mode = Control.FOCUS_ALL
	UiMotion.attach(comfort)
	comfort.pressed.connect(func(): open_comfort(container, comfort))
	container.add_child(comfort)
	var graphics := Button.new()
	graphics.name = "GraphicsButton"
	graphics.text = "Đồ họa: %s  ›" % GraphicsQuality.PRESET_NAMES[GraphicsQuality.preset()]
	graphics.focus_mode = Control.FOCUS_ALL
	UiMotion.attach(graphics)
	graphics.pressed.connect(func(): open_graphics(container, graphics))
	container.add_child(graphics)


## Keeps framing and shoulder choices on one compact row shared by menu and pause.
static func _camera_row(container: Container) -> void:
	container.add_theme_constant_override("separation", GameBalance.get_int("camera_settings_row_gap"))
	var row := HBoxContainer.new()
	row.name = "CameraChoices"
	row.add_theme_constant_override("separation", GameBalance.get_int("camera_settings_gap"))
	for entry in [["CameraView", "Góc camera", ["Gần", "Vừa", "Xa"], SessionState.camera_view], ["CameraSide", "Vai camera", ["Phải", "Trái"], SessionState.camera_side]]:
		var label := Label.new()
		label.text = entry[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var choice := OptionButton.new()
		choice.name = entry[0]
		choice.custom_minimum_size.x = GameBalance.get_number("camera_choice_width")
		choice.focus_mode = Control.FOCUS_ALL
		for text: String in entry[2]:
			choice.add_item(text)
		choice.select(entry[3])
		var is_view: bool = entry[0] == "CameraView"
		choice.item_selected.connect(func(index: int):
			if is_view:
				SessionState.camera_view = index
			else:
				SessionState.camera_side = index
			SessionState.save_settings()
		)
		UiMotion.attach(choice)
		row.add_child(choice)
	container.add_child(row)


## Opens the Đồ họa page over the settings: a preset row, one row per detail option and
## the FPS toggle. It is a top-level child of `container`, so it closes with the settings.
static func open_graphics(container: Container, opener: Button) -> Control:
	var page := Control.new()
	page.name = "GraphicsPage"
	page.top_level = true
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(page)
	var covered: Array[Control] = []
	for control: Control in container.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL:
			covered.append(control)
			control.focus_mode = Control.FOCUS_NONE
	var dim := ColorRect.new()
	dim.color = Color("#1E1914B0")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#30281F")
	style.border_color = Color("#8A5A3B")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(GameBalance.get_number("ui_graphics_page_width", 560), 0)
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", GameBalance.get_int("ui_graphics_row_gap", 10))
	panel.add_child(rows)
	var title := Label.new()
	title.text = "ĐỒ HỌA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameBalance.get_int("ui_graphics_title_font_size", 30))
	title.add_theme_color_override("font_color", Color("#E8BC65"))
	rows.add_child(title)
	var preset := _choice_row(rows, "Chất lượng", GraphicsQuality.PRESET_NAMES.slice(0, 3))
	var details: Array[OptionButton] = []
	for entry in GraphicsQuality.DETAILS:
		details.append(_choice_row(rows, entry[1], entry[2]))
	var refresh := func():
		var current := GraphicsQuality.preset()
		if current == GraphicsQuality.CUSTOM:
			if preset.item_count < 4:
				preset.add_item(GraphicsQuality.PRESET_NAMES[GraphicsQuality.CUSTOM])
				preset.set_item_disabled(3, true)
		elif preset.item_count > 3:
			preset.remove_item(3)
		preset.select(current)
		for index in details.size():
			details[index].select(GraphicsQuality.detail(GraphicsQuality.DETAILS[index][0]))
		opener.text = "Đồ họa: %s  ›" % GraphicsQuality.PRESET_NAMES[current]
	refresh.call()
	preset.item_selected.connect(func(index: int):
		if index < 3:
			GraphicsQuality.set_preset(index)
		refresh.call()
	)
	for index in details.size():
		var key: String = GraphicsQuality.DETAILS[index][0]
		details[index].item_selected.connect(func(value: int):
			GraphicsQuality.set_detail(key, value)
			refresh.call()
		)
	var limit := _choice_row(rows, "Giới hạn FPS", GraphicsQuality.FPS_LIMIT_NAMES)
	limit.select(GraphicsQuality.fps_limit())
	limit.item_selected.connect(GraphicsQuality.set_fps_limit)
	var fps := CheckButton.new()
	style_toggle(fps)
	fps.text = "Hiện FPS"
	fps.button_pressed = GraphicsQuality.show_fps()
	fps.toggled.connect(GraphicsQuality.set_show_fps)
	rows.add_child(fps)
	var note := Label.new()
	note.text = "Khán giả, bóng đổ và môi trường đổi từ trận sau."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", GameBalance.get_int("ui_graphics_note_font_size", 14))
	note.add_theme_color_override("font_color", Color("#C9B48A"))
	rows.add_child(note)
	var done := Button.new()
	done.name = "GraphicsDone"
	done.text = "XONG"
	done.custom_minimum_size = Vector2(240, 48)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiMotion.attach(done)
	done.pressed.connect(func():
		container.remove_child(page)
		page.queue_free()
		for control in covered:
			if is_instance_valid(control):
				control.focus_mode = Control.FOCUS_ALL
		if is_instance_valid(opener):
			opener.grab_focus()
	)
	rows.add_child(done)
	preset.grab_focus()
	return page


static func open_comfort(container: Container, opener: Button) -> Control:
	var page := Control.new()
	page.name = "ComfortPage"
	page.top_level = true
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(page)
	# Keep the covered controls out of keyboard/gamepad navigation until XONG.
	var covered: Array[Control] = []
	for control: Control in container.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL:
			covered.append(control)
			control.focus_mode = Control.FOCUS_NONE
	var dim := ColorRect.new()
	dim.color = Color("#1E1914B0")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#30281F")
	style.border_color = Color("#8A5A3B")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = GameBalance.get_number("ui_comfort_page_width")
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", GameBalance.get_int("ui_comfort_row_gap"))
	panel.add_child(rows)
	var title := Label.new()
	title.text = "HIỆU ỨNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#E8BC65"))
	rows.add_child(title)
	var first: Control
	for entry in [
		["CameraShake", "Rung camera", SessionState.camera_shake_enabled, func(enabled: bool): SessionState.camera_shake_enabled = enabled],
		["CameraPunch", "Giật camera khi trúng đòn", SessionState.camera_punch_enabled, func(enabled: bool): SessionState.camera_punch_enabled = enabled],
		["ImpactFlash", "Chớp sáng khi trúng đòn", SessionState.impact_flash, func(index: int): SessionState.impact_flash = index],
		["Hitstop", "Khựng khi trúng đòn", SessionState.hitstop_enabled, func(enabled: bool): SessionState.hitstop_enabled = enabled],
		["AutoPause", "Tự tạm dừng khi rời cửa sổ", SessionState.auto_pause_enabled, func(enabled: bool): SessionState.auto_pause_enabled = enabled],
		["Rumble", "Rung tay cầm", SessionState.rumble_enabled, func(enabled: bool): SessionState.rumble_enabled = enabled],
		["Replay", "Xem lại pha quyết định", SessionState.replay_enabled, func(enabled: bool): SessionState.replay_enabled = enabled]
	]:
		var update: Callable = entry[3]
		var control: Control
		if entry[0] == "ImpactFlash":
			var option := _choice_row(rows, entry[1], ["Đầy đủ", "Dịu", "Tắt"])
			option.select(entry[2])
			option.item_selected.connect(func(index: int):
				update.call(index)
				SessionState.save_settings()
			)
			UiMotion.attach(option)
			control = option
		else:
			var toggle := CheckButton.new()
			style_toggle(toggle)
			toggle.text = entry[1]
			toggle.button_pressed = entry[2]
			toggle.toggled.connect(func(enabled: bool):
				update.call(enabled)
				SessionState.save_settings()
			)
			rows.add_child(toggle)
			control = toggle
		control.name = entry[0]
		control.custom_minimum_size.y = GameBalance.get_number("ui_comfort_choice_height")
		if first == null:
			first = control
		if entry[0] == "Hitstop":
			var note := Label.new()
			note.text = "Chỉ áp dụng khi đấu Solo"
			note.add_theme_font_size_override("font_size", 14)
			note.add_theme_color_override("font_color", Color("#C9B48A"))
			rows.add_child(note)
	var text_size := _choice_row(rows, "Cỡ chữ HUD", ["Thường", "Lớn"])
	text_size.name = "HudTextSize"
	text_size.select(1 if SessionState.hud_text_large else 0)
	text_size.custom_minimum_size.y = GameBalance.get_number("ui_comfort_choice_height")
	text_size.item_selected.connect(func(index: int):
		SessionState.hud_text_large = index == 1
		SessionState.save_settings()
	)
	var done := Button.new()
	done.name = "ComfortDone"
	done.text = "XONG"
	done.custom_minimum_size = Vector2(240, 48)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiMotion.attach(done)
	done.pressed.connect(func():
		container.remove_child(page)
		page.queue_free()
		for control in covered:
			if is_instance_valid(control):
				control.focus_mode = Control.FOCUS_ALL
		if is_instance_valid(opener):
			opener.grab_focus()
	)
	rows.add_child(done)
	first.grab_focus()
	return page


static func close_comfort(container: Container) -> bool:
	var page := container.get_node_or_null("ComfortPage")
	if page == null:
		return false
	(page.find_child("ComfortDone", true, false) as Button).pressed.emit()
	return true


static func close_graphics(container: Container) -> bool:
	var page := container.get_node_or_null("GraphicsPage")
	if page == null:
		return false
	(page.find_child("GraphicsDone", true, false) as Button).pressed.emit()
	return true


static func _choice_row(rows: VBoxContainer, label_text: String, choices: Array) -> OptionButton:
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(GameBalance.get_number("ui_graphics_option_width", 170), 0)
	option.focus_mode = Control.FOCUS_ALL
	for choice in choices:
		option.add_item(choice)
	line.add_child(option)
	rows.add_child(line)
	return option


static func style_toggle(button: CheckButton) -> void:
	UiMotion.attach(button)
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
