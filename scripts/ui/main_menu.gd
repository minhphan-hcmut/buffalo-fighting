extends Control

const ARENA_SCENE := "res://scenes/arena.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var menu_layout: VBoxContainer
var ceremony_layer: Control
var result_title: Label
var result_detail: Label
var result_actions: VBoxContainer
var displayed_result := ""
var menu_settings_layer: Control
var menu_settings_actions: VBoxContainer


func _ready() -> void:
	if get_meta("session_overlay", false):
		process_mode = Node.PROCESS_MODE_ALWAYS
		_build_session_overlay()
		return
	_build_main_menu()


func _process(_delta: float) -> void:
	if not get_meta("session_overlay", false):
		return
	var scene := get_tree().current_scene
	if not scene is MatchController:
		hide()
		return
	var is_solo_result: bool = SessionState.mode == &"SOLO" and scene.get("phase") == &"RESULT"
	visible = is_solo_result
	if is_solo_result:
		var result_key := "%s:%s:%s" % [
			SessionState.last_match_level,
			SessionState.last_winner,
			SessionState.last_reason
		]
		if result_key != displayed_result:
			_show_result(result_key)


func _build_main_menu() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#33546D")
	add_child(background)

	menu_layout = _make_centered_layout(Vector2(440, 480))
	add_child(menu_layout)
	var title := _make_label("CHỌI TRÂU", 58, Color("#F2E6CF"))
	menu_layout.add_child(title)
	var subtitle := _make_label("ĐẤU TRƯỜNG LỄ HỘI · 2.5D · GÓC NHÌN 45°", 20, Color("#E8BC65"))
	menu_layout.add_child(subtitle)

	var solo := _button("SOLO · MÙA HỘI")
	solo.pressed.connect(_start_solo)
	menu_layout.add_child(solo)
	var lan := _button("LAN · HOST / JOIN")
	lan.pressed.connect(_start_lan)
	menu_layout.add_child(lan)
	var settings := _button("CÀI ĐẶT")
	settings.pressed.connect(_show_settings)
	menu_layout.add_child(settings)
	var quit := _button("THOÁT")
	quit.pressed.connect(func(): get_tree().quit())
	menu_layout.add_child(quit)
	menu_layout.add_child(_make_label("Vòng loại · Bán kết · Chung kết", 16, Color("#F2E6CF")))


func _show_settings() -> void:
	if is_instance_valid(menu_settings_layer):
		menu_settings_layer.visible = true
		return
	menu_settings_layer = Control.new()
	menu_settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_settings_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#17262EE8")
	menu_settings_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -310)
	panel.size = Vector2(520, 620)
	menu_settings_layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := _make_label("CÀI ĐẶT", 30, Color("#E8BC65"))
	content.add_child(title)
	var detail := _make_label("Âm lượng áp dụng cho các bus audio của project.", 15, Color("#F2E6CF"))
	content.add_child(detail)
	menu_settings_actions = VBoxContainer.new()
	menu_settings_actions.add_theme_constant_override("separation", 8)
	content.add_child(menu_settings_actions)
	_add_menu_audio_slider("Âm lượng tổng", "Master")
	_add_menu_audio_slider("Nhạc", "Music")
	_add_menu_audio_slider("Hiệu ứng", "SFX")
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.03
	sensitivity.max_value = 0.5
	sensitivity.step = 0.01
	sensitivity.value = SessionState.get_mouse_sensitivity()
	sensitivity.value_changed.connect(func(value: float): SessionState.mouse_sensitivity = value)
	menu_settings_actions.add_child(_menu_labeled_control("Độ nhạy chuột", sensitivity))
	var fullscreen := CheckButton.new()
	fullscreen.text = "Toàn màn hình"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(_set_menu_fullscreen)
	menu_settings_actions.add_child(fullscreen)
	var shake := CheckButton.new()
	shake.text = "Rung camera"
	shake.button_pressed = SessionState.camera_shake_enabled
	shake.toggled.connect(func(enabled: bool): SessionState.camera_shake_enabled = enabled)
	menu_settings_actions.add_child(shake)
	var close := _button("QUAY LẠI")
	close.pressed.connect(func(): menu_settings_layer.hide())
	menu_settings_actions.add_child(close)


func _add_menu_audio_slider(label_text: String, bus_name: StringName) -> void:
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
	menu_settings_actions.add_child(_menu_labeled_control(label_text, slider))


func _menu_labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	row.add_child(control)
	return row


func _set_menu_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _make_centered_layout(size: Vector2) -> VBoxContainer:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_CENTER)
	layout.position = -size * 0.5
	layout.size = size
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	return layout


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	return button


func _start_solo() -> void:
	var show_opening := SessionState.begin_solo()
	if show_opening:
		_show_opening_ceremony()
	else:
		_enter_arena()


func _show_opening_ceremony() -> void:
	menu_layout.hide()
	ceremony_layer = _make_ceremony_layer(
		"KHAI HỘI",
		"Cờ hội được thượng. Trống điểm khai hội.\nCầu mùa hội an toàn, biển lặng, ngư dân ra khơi bình an."
	)
	var enter := _button("VÀO MÙA HỘI")
	enter.pressed.connect(_enter_arena)
	ceremony_layer.get_node("Content").add_child(enter)
	add_child(ceremony_layer)
	enter.grab_focus()


func _make_ceremony_layer(title_text: String, body_text: String) -> Control:
	var layer := Control.new()
	layer.name = "Ceremony"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#243A45")
	layer.add_child(background)
	var content := _make_centered_layout(Vector2(760, 390))
	content.name = "Content"
	layer.add_child(content)
	content.add_child(_make_label(title_text, 40, Color("#E8BC65")))
	content.add_child(_make_label(body_text, 24, Color("#F2E6CF")))
	return layer


func _enter_arena() -> void:
	if is_instance_valid(ceremony_layer):
		ceremony_layer.queue_free()
	if is_instance_valid(menu_layout):
		menu_layout.hide()
	_ensure_session_overlay()
	get_tree().change_scene_to_file(ARENA_SCENE)


func _ensure_session_overlay() -> void:
	var root := get_tree().root
	var overlay := root.get_node_or_null("SoloSessionOverlay")
	if overlay != null:
		return
	overlay = Control.new()
	overlay.name = "SoloSessionOverlay"
	overlay.set_script(get_script())
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)


func _build_session_overlay() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	hide()
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#17262EDC")
	add_child(background)
	var content := _make_centered_layout(Vector2(760, 480))
	add_child(content)
	result_title = _make_label("", 40, Color("#E8BC65"))
	content.add_child(result_title)
	result_detail = _make_label("", 24, Color("#F2E6CF"))
	content.add_child(result_detail)
	result_actions = VBoxContainer.new()
	result_actions.add_theme_constant_override("separation", 12)
	content.add_child(result_actions)


func _show_result(result_key: String) -> void:
	displayed_result = result_key
	for child in result_actions.get_children():
		child.queue_free()

	var level := SessionState.last_match_level
	var won := SessionState.last_winner == 1
	var final_win := won and level == &"L03"
	if final_win:
		result_title.text = "KHÉP MÙA HỘI"
		result_detail.text = "Ông trâu vô địch được rước về đình.\nLễ tạ ơn, tiễn thần khép mùa hội."
	else:
		result_title.text = "KẾT QUẢ · %s" % _round_name(level)
		var winner := "Ông trâu số 06" if won else "Ông trâu đối phương"
		var reason: String = {
			&"FLEE": "thắng thế, đối phương chịu thua và lui sới",
			&"TIME": "khí thế cao hơn khi hết giờ",
			&"LOT": "thắng bốc thăm"
		}.get(SessionState.last_reason, "trận đấu kết thúc")
		result_detail.text = "%s · %s" % [winner, reason]

	var retry := _button("CHƠI LẠI TRẬN NÀY")
	retry.pressed.connect(_retry_match)
	result_actions.add_child(retry)
	if won and not final_win:
		var next := _button("TRẬN TIẾP THEO · %s" % _round_name(SessionState.level_id))
		next.pressed.connect(_start_next_match)
		result_actions.add_child(next)
	var menu := _button("VỀ MENU")
	menu.pressed.connect(_return_to_menu)
	result_actions.add_child(menu)
	retry.grab_focus()


func _round_name(level: StringName) -> String:
	return {
		&"L01": "VÒNG LOẠI",
		&"L02": "BÁN KẾT",
		&"L03": "CHUNG KẾT"
	}.get(level, "MÙA HỘI")


func _retry_match() -> void:
	SessionState.retry()
	get_tree().change_scene_to_file(ARENA_SCENE)


func _start_next_match() -> void:
	SessionState.begin_solo()
	get_tree().change_scene_to_file(ARENA_SCENE)


func _return_to_menu() -> void:
	SessionState.return_to_menu()
	displayed_result = ""
	hide()
	get_tree().change_scene_to_file(MENU_SCENE)


func _start_lan() -> void:
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	get_tree().change_scene_to_file(LOBBY_SCENE)
