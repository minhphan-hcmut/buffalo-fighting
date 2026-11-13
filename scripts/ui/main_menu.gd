extends Control
## Main menu (Solo, LAN, settings, quit) and the Solo flow around matches: the opening
## Phần Lễ before the first match, then a copy of this script stays on the root as
## "SoloSessionOverlay" to show the result panel, next match and the closing Phần Lễ.

const ARENA_SCENE := "res://scenes/arena.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var menu_layout: VBoxContainer
var ceremony_layer: Control
var result_title: Label
var result_detail: Label
var result_actions: VBoxContainer
var result_panel: PanelContainer
var displayed_result := ""
var menu_settings_layer: Control
var menu_settings_actions: VBoxContainer


func _ready() -> void:
	if get_meta("session_overlay", false):
		process_mode = Node.PROCESS_MODE_ALWAYS
		_build_session_overlay()
		return
	(get_node("/root/GameAudio") as FestivalAudio).play_music("music_festival_loop", true)
	_build_main_menu()


func _process(_delta: float) -> void:
	if not get_meta("session_overlay", false):
		return
	var scene := get_tree().current_scene
	if not scene is MatchController:
		hide()
		return
	var is_solo_result: bool = SessionState.mode == &"SOLO" and scene.get("phase") == &"RESULT" and scene.get("result_ready")
	visible = is_solo_result
	scene.hud.visible = not is_solo_result
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
	_build_backdrop()
	menu_layout = VBoxContainer.new()
	menu_layout.anchor_top = 0.5
	menu_layout.anchor_bottom = 0.5
	menu_layout.offset_left = 88.0
	menu_layout.offset_right = 88.0 + 440.0
	menu_layout.offset_top = -250.0
	menu_layout.offset_bottom = 250.0
	menu_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_layout.add_theme_constant_override("separation", 18)
	add_child(menu_layout)
	var title := _make_label("CHỌI TRÂU", 72, Color("#E8BC65"))
	title.add_theme_color_override("font_outline_color", Color("#241D18"))
	title.add_theme_constant_override("outline_size", 10)
	menu_layout.add_child(title)
	var subtitle := _make_label("ĐẤU TRƯỜNG LỄ HỘI", 24, Color("#F2E6CF"))
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
	menu_layout.add_child(_make_label("Vòng loại · Bán kết · Chung kết", 18, Color("#D9C9A8")))
	solo.grab_focus()


## The festival arena in 3D (MenuBackdrop) behind the menu, darkened on the left so the
## menu column stays readable.
func _build_backdrop() -> void:
	var container := SubViewportContainer.new()
	container.name = "Backdrop"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var backdrop := MenuBackdrop.new()
	backdrop.name = "MenuBackdrop"
	viewport.add_child(backdrop)
	add_child(_make_left_shade())


## Full-screen shade, dark on the left fading to clear past the middle: keeps a left
## column of text readable over a 3D scene (menu backdrop, Solo result winner shot).
func _make_left_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 0.62])
	gradient.colors = PackedColorArray([Color("#17120EE6"), Color("#17120EB0"), Color("#17120E00")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	var shade := TextureRect.new()
	shade.name = "LeftShade"
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade


func _show_settings() -> void:
	if is_instance_valid(menu_settings_layer):
		menu_settings_layer.visible = true
		menu_layout.hide()
		menu_settings_actions.get_child(0).get_child(1).grab_focus()
		return
	menu_layout.hide()
	menu_settings_layer = Control.new()
	menu_settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_settings_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#17262EE8")
	menu_settings_layer.add_child(shade)
	var panel := PanelContainer.new()
	menu_settings_layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -310
	panel.offset_bottom = 310
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
	SettingsControls.populate(menu_settings_actions)
	var close := _button("QUAY LẠI")
	close.pressed.connect(func():
		menu_settings_layer.hide()
		menu_layout.show()
		menu_layout.get_child(4).grab_focus()
	)
	menu_settings_actions.add_child(close)
	menu_settings_actions.get_child(0).get_child(1).grab_focus()


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
	var view := CeremonyView.create(&"opening")
	view.finished.connect(_enter_arena)
	ceremony_layer = view
	add_child(view)


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
	# The winner stands in the arena on the right (FollowCamera.show_winner); the result
	# sits in a left column over a shade, as on the main menu.
	add_child(_make_left_shade())
	var panel := PanelContainer.new()
	result_panel = panel
	add_child(panel)
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 64.0
	panel.offset_right = 64.0 + 540.0
	panel.offset_top = -230.0
	panel.offset_bottom = 230.0
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	panel.add_child(content)
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
	if final_win:
		_show_closing_ceremony(retry)
	else:
		retry.grab_focus()


## GDD Bảng 17 closing rite: shown once over the final result, then the result actions return.
func _show_closing_ceremony(focus_after: Button) -> void:
	result_panel.hide()
	var view := CeremonyView.create(&"closing")
	view.finished.connect(func():
		view.queue_free()
		result_panel.show()
		focus_after.grab_focus()
	)
	add_child(view)


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
