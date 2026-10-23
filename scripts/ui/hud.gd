extends CanvasLayer
## Read-only match presentation; combat state is supplied by MatchController.

var controller: MatchController
var player_spirit: ProgressBar
var player_stamina: ProgressBar
var opponent_spirit: ProgressBar
var opponent_stamina: ProgressBar
var timer_label: Label
var center_label: Label
var result_label: Label
var clash_label: Label
var tutorial_label: Label
var pause_overlay: Control
var pause_panel: PanelContainer
var pause_title: Label
var pause_detail: Label
var pause_actions: VBoxContainer


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var top := HBoxContainer.new()
	top.position = Vector2(24, 20)
	top.size = Vector2(1232, 90)
	top.add_theme_constant_override("separation", 26)
	root.add_child(top)
	var left := _make_player_panel("ĐỎ · 06 · GIÁP ĐÔNG", Color("#B6453B"))
	top.add_child(left)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var right := _make_player_panel("XANH · 17 · GIÁP TÂY", Color("#33546D"))
	top.add_child(right)
	timer_label = Label.new()
	timer_label.position = Vector2(590, 26)
	timer_label.size = Vector2(100, 38)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 24)
	root.add_child(timer_label)
	center_label = Label.new()
	center_label.position = Vector2(400, 245)
	center_label.size = Vector2(480, 90)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 42)
	center_label.add_theme_color_override("font_color", Color("#F2E6CF"))
	root.add_child(center_label)
	clash_label = Label.new()
	clash_label.position = Vector2(490, 118)
	clash_label.size = Vector2(300, 34)
	clash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_label.add_theme_font_size_override("font_size", 22)
	clash_label.add_theme_color_override("font_color", Color("#E8BC65"))
	root.add_child(clash_label)
	tutorial_label = Label.new()
	tutorial_label.position = Vector2(24, 665)
	tutorial_label.size = Vector2(1232, 32)
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_font_size_override("font_size", 16)
	tutorial_label.text = "WASD Đi · Chuột Nhìn · Trái Húc · Space Hổ lao · Phải Ghìm · Esc Tạm dừng"
	root.add_child(tutorial_label)
	result_label = Label.new()
	result_label.position = Vector2(330, 340)
	result_label.size = Vector2(620, 120)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 30)
	result_label.add_theme_color_override("font_color", Color("#F2E6CF"))
	root.add_child(result_label)
	# The in-match HUD is display-only: let clicks through so CameraRig can capture the mouse.
	_ignore_mouse(root)
	_build_pause_overlay(root)


func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)


func _build_pause_overlay(root: Control) -> void:
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	root.add_child(pause_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#17262EE8")
	pause_overlay.add_child(shade)
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-260, -220)
	pause_panel.size = Vector2(520, 440)
	pause_overlay.add_child(pause_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	pause_panel.add_child(content)
	pause_title = Label.new()
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 30)
	content.add_child(pause_title)
	pause_detail = Label.new()
	pause_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(pause_detail)
	pause_actions = VBoxContainer.new()
	pause_actions.add_theme_constant_override("separation", 10)
	content.add_child(pause_actions)


func _clear_pause_actions() -> void:
	for child in pause_actions.get_children():
		child.queue_free()


func _pause_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	pause_actions.add_child(button)


func show_pause() -> void:
	pause_overlay.visible = true
	pause_panel.position = Vector2(-260, -220)
	pause_panel.size = Vector2(520, 440)
	pause_title.text = "TẠM DỪNG" if controller.mode == &"SOLO" else "TRẬN LAN ĐANG TẠM DỪNG"
	pause_detail.text = "Trận solo đã dừng." if controller.mode == &"SOLO" else "Hai người chơi đã đồng ý tạm dừng."
	_clear_pause_actions()
	if controller.mode == &"LAN":
		_pause_button("GỬI YÊU CẦU TIẾP TỤC", controller.resume_from_menu)
	else:
		_pause_button("TIẾP TỤC", controller.resume_from_menu)
	_pause_button("CÀI ĐẶT", show_settings)
	_pause_button("CHƠI LẠI", _restart_match)
	_pause_button("VỀ MENU", _return_to_menu)
	pause_actions.get_child(0).grab_focus()


func show_pause_wait(requested_pause: bool) -> void:
	pause_overlay.visible = true
	pause_panel.position = Vector2(-260, -220)
	pause_panel.size = Vector2(520, 440)
	pause_title.text = "ĐANG CHỜ XÁC NHẬN"
	pause_detail.text = (
		"Yêu cầu tạm dừng đã gửi tới đối phương."
		if requested_pause
		else "Yêu cầu tiếp tục trận đã gửi tới đối phương."
	)
	_clear_pause_actions()
	_pause_button("CÀI ĐẶT", show_settings)
	_pause_button("RỜI TRẬN", _return_to_menu)


func show_pause_confirmation(peer_id: int, requested_pause: bool) -> void:
	pause_overlay.visible = true
	pause_panel.position = Vector2(-260, -190)
	pause_panel.size = Vector2(520, 380)
	pause_title.text = "YÊU CẦU TỪ NGƯỜI CHƠI %d" % peer_id
	pause_detail.text = (
		"Đối phương muốn tạm dừng trận."
		if requested_pause
		else "Đối phương muốn tiếp tục trận."
	)
	_clear_pause_actions()
	_pause_button("CHẤP NHẬN", func(): controller.network.answer_pause(true))
	_pause_button("TỪ CHỐI", func(): controller.network.answer_pause(false))


func hide_pause() -> void:
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = false


func show_settings() -> void:
	pause_overlay.visible = true
	pause_panel.position = Vector2(-260, -310)
	pause_panel.size = Vector2(520, 620)
	pause_title.text = "CÀI ĐẶT"
	pause_detail.text = "Âm lượng áp dụng cho các bus audio của project."
	_clear_pause_actions()
	_add_audio_slider("Âm lượng tổng", "Master")
	_add_audio_slider("Nhạc", "Music")
	_add_audio_slider("Hiệu ứng", "SFX")
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.03
	sensitivity.max_value = 0.5
	sensitivity.step = 0.01
	sensitivity.value = SessionState.get_mouse_sensitivity()
	pause_actions.add_child(_labeled_control("Độ nhạy chuột", sensitivity))
	sensitivity.value_changed.connect(_set_mouse_sensitivity)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Toàn màn hình"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(_set_fullscreen)
	pause_actions.add_child(fullscreen)
	var shake := CheckButton.new()
	shake.text = "Rung camera"
	shake.button_pressed = SessionState.camera_shake_enabled
	shake.toggled.connect(func(enabled: bool): SessionState.camera_shake_enabled = enabled)
	pause_actions.add_child(shake)
	_pause_button("QUAY LẠI", show_pause)


func _add_audio_slider(label_text: String, bus_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = AudioServer.get_bus_volume_linear(bus_index) * 100.0
	slider.value_changed.connect(
		func(value: float): AudioServer.set_bus_volume_linear(bus_index, value / 100.0)
	)
	pause_actions.add_child(_labeled_control(label_text, slider))


func _labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	row.add_child(control)
	return row


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _set_mouse_sensitivity(value: float) -> void:
	SessionState.mouse_sensitivity = value
	controller.get_node("CameraRig").mouse_sensitivity = value


func _restart_match() -> void:
	if controller.mode == &"LAN":
		controller.network.leave()
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	if controller.mode == &"LAN":
		controller.network.leave()
	SessionState.return_to_menu()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _make_player_panel(title: String, color: Color) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(390, 86)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)
	title_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(title_label)
	var spirit := ProgressBar.new()
	spirit.max_value = 100.0
	spirit.custom_minimum_size = Vector2(390, 24)
	spirit.show_percentage = false
	spirit.add_theme_stylebox_override("fill", _bar_style(color))
	panel.add_child(spirit)
	var stamina := ProgressBar.new()
	stamina.max_value = 100.0
	stamina.custom_minimum_size = Vector2(390, 14)
	stamina.show_percentage = false
	stamina.add_theme_stylebox_override("fill", _bar_style(Color("#E8BC65")))
	panel.add_child(stamina)
	if player_spirit == null:
		player_spirit = spirit
		player_stamina = stamina
	else:
		opponent_spirit = spirit
		opponent_stamina = stamina
	return panel


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _process(_delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		return
	player_spirit.value = controller.player.spirit
	player_stamina.value = controller.player.stamina
	opponent_spirit.value = controller.opponent.spirit
	opponent_stamina.value = controller.opponent.stamina
	timer_label.text = "%02d:%02d" % [int(controller.remaining_time) / 60, int(controller.remaining_time) % 60]
	center_label.text = "CÒN %.1f" % controller.countdown_time if controller.phase == &"COUNTDOWN" else ""
	if controller.phase == &"PLAYING":
		tutorial_label.text = "WASD Đi · Chuột Nhìn · Trái Húc · Space Hổ lao · Phải Ghìm · Esc Tạm dừng"
	elif controller.phase == &"RESULT":
		tutorial_label.text = "Kết quả đã khóa · bấm Esc để thả chuột"
	if controller.active_clash.is_empty():
		clash_label.text = ""
	else:
		clash_label.text = "CLASH  %+.0f" % float(controller.active_clash.get("balance", 0.0))


func show_result(winner_slot: int, reason: StringName) -> void:
	var winner := "ÔNG TRÂU ĐỎ" if winner_slot == 1 else "ÔNG TRÂU XANH"
	var reason_text: String = {
		&"FLEE": "THẮNG THẾ · ĐỐI PHƯƠNG LUI SỚI",
		&"TIME": "THẮNG THỜI GIAN · KHÍ THẾ CAO HƠN",
		&"LOT": "BỐC THĂM · LOT"
	}.get(reason, "TRẬN KẾT THÚC")
	result_label.visible = controller.mode == &"LAN"
	result_label.text = "%s\n%s" % [winner, reason_text]
