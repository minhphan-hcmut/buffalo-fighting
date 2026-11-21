class_name SettingsControls
extends RefCounted
## Shared rows and bindings; saving and live application remain in their existing owners.

const MUTED := Color("#C9B48A")
const PANEL := Color("#30281F")
const EFFECTS := [
	["CameraShake", "Rung camera", "camera_shake_enabled", ""],
	["CameraPunch", "Giật camera khi trúng đòn", "camera_punch_enabled", ""],
	["ImpactFlash", "Chớp sáng khi trúng đòn", "impact_flash", ""],
	["Hitstop", "Khựng khi trúng đòn", "hitstop_enabled", "Chỉ áp dụng khi đấu Solo"],
	["AutoPause", "Tự tạm dừng khi rời cửa sổ", "auto_pause_enabled", "Chỉ áp dụng khi đấu Solo"],
	["Rumble", "Rung tay cầm", "rumble_enabled", ""],
	["Replay", "Xem lại pha quyết định", "replay_enabled", "Chỉ áp dụng khi đấu Solo"],
	["HudTextSize", "Cỡ chữ HUD", "hud_text_large", ""],
]


static func populate(container: VBoxContainer, tab: int, on_sensitivity: Callable = Callable()) -> void:
	container.add_theme_constant_override("separation", 0)
	match tab:
		0:
			for entry in [["Master", "Âm lượng tổng"], ["Music", "Nhạc"], ["SFX", "Hiệu ứng"]]:
				var bus := FestivalAudio.ensure_bus(entry[0])
				var slider := HSlider.new()
				slider.max_value = 100.0
				slider.step = 1.0
				slider.value = AudioServer.get_bus_volume_linear(bus) * 100.0
				slider.value_changed.connect(func(value: float):
					AudioServer.set_bus_volume_linear(bus, value / 100.0)
					SessionState.save_settings()
				)
				_slider(container, entry[0], entry[1], slider)
		1:
			var sensitivity := HSlider.new()
			sensitivity.max_value = 1.0
			sensitivity.step = GameBalance.get_number("ui_settings_sensitivity_slider_step")
			var baseline := GameBalance.get_number("mouse_sensitivity")
			var minimum := GameBalance.get_number("ui_settings_sensitivity_min")
			var maximum := GameBalance.get_number("ui_settings_sensitivity_max")
			var current := SessionState.get_mouse_sensitivity()
			sensitivity.value = 0.5 * inverse_lerp(minimum, baseline, current) if current <= baseline else 0.5 + 0.5 * inverse_lerp(baseline, maximum, current)
			sensitivity.value_changed.connect(func(value: float):
				var actual := lerpf(minimum, baseline, value * 2.0) if value <= 0.5 else lerpf(baseline, maximum, (value - 0.5) * 2.0)
				SessionState.mouse_sensitivity = actual
				SessionState.save_settings()
				if on_sensitivity.is_valid():
					on_sensitivity.call(actual)
			)
			# Named in both languages so a player can find it in either.
			var language := _choice(container, "Language", "Ngôn ngữ / Language", Language.NAMES)
			language.select(Language.index())
			language.item_selected.connect(func(index: int):
				Language.apply(Language.CODES[index])
				SessionState.save_settings()
			)
			_slider(container, "Sensitivity", "Độ nhạy chuột", sensitivity)
			_toggle(container, "Fullscreen", "Toàn màn hình", SessionState.fullscreen_enabled, set_fullscreen)
			var buttons: Array[KeyBindButton] = []
			for entry in KeyBindings.ACTIONS:
				var button := KeyBindButton.new(entry[0])
				buttons.append(button)
				container.add_child(SettingsRow.new("Key_" + entry[0], entry[1], button))
			for button in buttons:
				# A swapped binding changes another row too.
				button.rebound.connect(func(_action: String, _swapped: String):
					for other in buttons:
						other.refresh()
				)
		2:
			var view := _choice(container, "CameraView", "Góc camera", ["Gần", "Vừa", "Xa"])
			view.select(SessionState.camera_view)
			view.item_selected.connect(func(index: int):
				SessionState.camera_view = index
				SessionState.save_settings()
			)
			var side := _choice(container, "CameraSide", "Vai camera", ["Phải", "Trái"])
			side.select(SessionState.camera_side)
			side.item_selected.connect(func(index: int):
				SessionState.camera_side = index
				SessionState.save_settings()
			)
		3:
			var preset := _choice(container, "Preset", "Chất lượng", GraphicsQuality.PRESET_NAMES)
			preset.selectable_count = GraphicsQuality.CUSTOM
			var details: Array[SettingsSelector] = []
			for entry in GraphicsQuality.DETAILS:
				var hint := "Đổi từ trận sau" if entry[0] in ["crowd", "shadows", "scenery"] else ""
				var title: String = "Chi tiết model" if entry[0] == "models" else entry[1]
				details.append(_choice(container, entry[0], title, entry[2], hint))
			var refresh := func():
				preset.select(GraphicsQuality.preset())
				for index in details.size():
					details[index].select(GraphicsQuality.detail(GraphicsQuality.DETAILS[index][0]))
			refresh.call()
			preset.item_selected.connect(func(index: int):
				GraphicsQuality.set_preset(index)
				refresh.call()
			)
			for index in details.size():
				var key: String = GraphicsQuality.DETAILS[index][0]
				details[index].item_selected.connect(func(value: int):
					GraphicsQuality.set_detail(key, value)
					refresh.call()
				)
			var limit := _choice(container, "FpsLimit", "Giới hạn FPS", GraphicsQuality.FPS_LIMIT_NAMES)
			limit.select(GraphicsQuality.fps_limit())
			limit.item_selected.connect(GraphicsQuality.set_fps_limit)
			_toggle(container, "ShowFps", "Hiện FPS", GraphicsQuality.show_fps(), GraphicsQuality.set_show_fps)
		4:
			var values := effect_values()
			for entry in EFFECTS:
				var update := func(value: Variant):
					match entry[2]:
						"camera_shake_enabled": SessionState.camera_shake_enabled = value
						"camera_punch_enabled": SessionState.camera_punch_enabled = value
						"impact_flash": SessionState.impact_flash = value
						"hitstop_enabled": SessionState.hitstop_enabled = value
						"auto_pause_enabled": SessionState.auto_pause_enabled = value
						"rumble_enabled": SessionState.rumble_enabled = value
						"replay_enabled": SessionState.replay_enabled = value
						"hud_text_large": SessionState.hud_text_large = value == 1
					SessionState.save_settings()
				var current: Variant = values[entry[2]]
				if entry[0] in ["ImpactFlash", "HudTextSize"]:
					var option := _choice(container, entry[0], entry[1], ["Đầy đủ", "Dịu", "Tắt"] if entry[0] == "ImpactFlash" else ["Thường", "Lớn"], entry[3])
					option.select(int(current))
					option.item_selected.connect(update)
				else:
					_toggle(container, entry[0], entry[1], current, update, entry[3])


static func effect_values() -> Dictionary:
	return {
		"camera_shake_enabled": SessionState.camera_shake_enabled,
		"camera_punch_enabled": SessionState.camera_punch_enabled,
		"impact_flash": SessionState.impact_flash,
		"hitstop_enabled": SessionState.hitstop_enabled,
		"auto_pause_enabled": SessionState.auto_pause_enabled,
		"rumble_enabled": SessionState.rumble_enabled,
		"replay_enabled": SessionState.replay_enabled,
		"hud_text_large": SessionState.hud_text_large,
	}


static func reset_tab(container: VBoxContainer, tab: int) -> void:
	if tab == 3:
		GraphicsQuality.set_preset(GraphicsQuality.auto_preset())
		GraphicsQuality.set_fps_limit(0)
		GraphicsQuality.set_show_fps(false)
		(container.find_child("Preset", true, false) as SettingsSelector).select(GraphicsQuality.preset())
		for entry in GraphicsQuality.DETAILS:
			(container.find_child(entry[0], true, false) as SettingsSelector).select(GraphicsQuality.detail(entry[0]))
		(container.find_child("FpsLimit", true, false) as SettingsSelector).select(0)
		(container.find_child("ShowFps", true, false) as CheckButton).button_pressed = false
		return
	if tab == 1:
		KeyBindings.reset()
		SessionState.save_settings()
	for row: SettingsRow in container.get_children():
		var widget := row.control
		if widget is KeyBindButton:
			widget.refresh()
		elif widget is HSlider:
			widget.value = 100.0 if tab == 0 else 0.5
		elif widget is CheckButton:
			widget.button_pressed = tab == 4
		elif widget is SettingsSelector and widget.name == &"Language":
			continue  # Restoring control defaults keeps the language the player can read.
		elif widget is SettingsSelector:
			widget.select(1 if widget.name == &"CameraView" else 0)
			widget.item_selected.emit(widget.selected)


static func _choice(rows: VBoxContainer, key: String, title: String, values: Array, hint: String = "") -> SettingsSelector:
	var option := SettingsSelector.new(values)
	rows.add_child(SettingsRow.new(key, title, option, hint))
	return option


static func _toggle(rows: VBoxContainer, key: String, title: String, value: bool, update: Callable, hint: String = "") -> void:
	var toggle := CheckButton.new()
	style_toggle(toggle)
	toggle.button_pressed = value
	toggle.toggled.connect(update)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	rows.add_child(SettingsRow.new(key, title, toggle, hint))


static func _slider(rows: VBoxContainer, key: String, title: String, slider: HSlider) -> void:
	var row := SettingsRow.new(key, title, slider)
	var value := Label.new()
	value.name = "Value"
	value.custom_minimum_size.x = GameBalance.get_number("settings_value_width")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", ControlsDiagram.GOLD)
	value.add_theme_font_size_override("font_size", GameBalance.get_int("settings_label_size"))
	var update := func(number: float):
		if slider.max_value == 100.0:
			value.text = "%d%%" % roundi(number)
		else:
			var baseline := GameBalance.get_number("ui_settings_sensitivity_scale_default")
			var display := lerpf(GameBalance.get_number("ui_settings_sensitivity_scale_min"), baseline, number * 2.0) if number <= 0.5 else lerpf(baseline, GameBalance.get_number("ui_settings_sensitivity_scale_max"), (number - 0.5) * 2.0)
			value.text = ("%.1f" % display).trim_suffix(".0")
	slider.value_changed.connect(update)
	update.call(slider.value)
	row.column.add_child(value)
	rows.add_child(row)


static func row_style(active: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ControlsDiagram.GOLD, GameBalance.get_number("settings_highlight_alpha")) if active else Color.TRANSPARENT
	style.border_color = ControlsDiagram.GOLD if active else Color(MUTED, GameBalance.get_number("settings_divider_alpha"))
	style.border_width_left = GameBalance.get_int("settings_focus_width") if active else 0
	style.border_width_bottom = 1
	style.content_margin_left = GameBalance.get_number("settings_gap")
	style.content_margin_right = GameBalance.get_number("settings_gap")
	return style


static func quiet_button(button: Button) -> void:
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_hover_color", ControlsDiagram.GOLD)
	button.add_theme_color_override("font_pressed_color", ControlsDiagram.GOLD)
	button.add_theme_color_override("font_focus_color", ControlsDiagram.GOLD)
	button.add_theme_font_size_override("font_size", GameBalance.get_int("settings_label_size"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := row_style(state != "normal")
		style.border_width_bottom = 0
		button.add_theme_stylebox_override(state, style)


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


static func set_fullscreen(enabled: bool) -> void:
	SessionState.fullscreen_enabled = enabled
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
	SessionState.save_settings()
