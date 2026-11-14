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
# The arena (buffalo model, grass textures) loads on a thread while the menu and the rites
# are on screen, so entering a match no longer freezes for ~1.5 s. Kept for retries.
static var _arena_scene: PackedScene


func _ready() -> void:
	if get_meta("session_overlay", false):
		process_mode = Node.PROCESS_MODE_ALWAYS
		_build_session_overlay()
		return
	(get_node("/root/GameAudio") as FestivalAudio).play_music("music_festival_loop", true)
	_prefetch_arena()
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
	var howto := _button("CÁCH CHƠI")
	howto.name = "HowToPlayButton"
	howto.pressed.connect(_show_how_to_play)
	menu_layout.add_child(howto)
	var settings := _button("CÀI ĐẶT")
	settings.name = "SettingsButton"
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
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -GameBalance.get_number("ui_settings_panel_width") * 0.5
	panel.offset_right = GameBalance.get_number("ui_settings_panel_width") * 0.5
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := _make_label("CÀI ĐẶT", 30, Color("#E8BC65"))
	content.add_child(title)
	var detail := _make_label("Cài đặt được lưu tự động.", 15, Color("#F2E6CF"))
	content.add_child(detail)
	menu_settings_actions = VBoxContainer.new()
	menu_settings_actions.add_theme_constant_override("separation", 8)
	content.add_child(menu_settings_actions)
	SettingsControls.populate(menu_settings_actions)
	var close := _button("QUAY LẠI")
	close.pressed.connect(func():
		menu_settings_layer.hide()
		menu_layout.show()
		menu_layout.get_node("SettingsButton").grab_focus()
	)
	menu_settings_actions.add_child(close)
	menu_settings_actions.get_child(0).get_child(1).grab_focus()


func _show_how_to_play() -> void:
	if get_node_or_null("HowToPlay") != null:
		return
	menu_layout.hide()
	var howto := HowToPlay.new()
	howto.closed.connect(func():
		menu_layout.show()
		menu_layout.get_node("HowToPlayButton").grab_focus()
	)
	add_child(howto)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(menu_settings_layer) and menu_settings_layer.visible:
		menu_settings_actions.get_child(-1).pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


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
	var rites: Array[StringName] = []
	if SessionState.begin_solo():
		rites.append(&"opening")
	rites.append_array(SessionState.take_rites_before(SessionState.level_id))
	if rites.is_empty():
		_enter_arena()
	else:
		menu_layout.hide()
		_play_rites(rites, _enter_arena)


## Plays the Phần Lễ screens in `rites` one after another, then calls `done`.
func _play_rites(rites: Array[StringName], done: Callable) -> void:
	if is_instance_valid(ceremony_layer):
		ceremony_layer.queue_free()
	if rites.is_empty():
		done.call()
		return
	var view := CeremonyView.create(rites[0])
	var rest := rites.slice(1)
	view.finished.connect(func(): _play_rites(rest, done))
	ceremony_layer = view
	add_child(view)


func _enter_arena() -> void:
	if is_instance_valid(ceremony_layer):
		ceremony_layer.queue_free()
	if is_instance_valid(menu_layout):
		menu_layout.hide()
	_ensure_session_overlay()
	_go_to_arena()


static func _prefetch_arena() -> void:
	if _arena_scene == null and ResourceLoader.load_threaded_get_status(ARENA_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(ARENA_SCENE)


func _go_to_arena() -> void:
	if _arena_scene == null:
		var requested := ResourceLoader.load_threaded_get_status(ARENA_SCENE) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		# load_threaded_get() waits for a load still in flight.
		_arena_scene = ResourceLoader.load_threaded_get(ARENA_SCENE) if requested else load(ARENA_SCENE)
	get_tree().change_scene_to_packed(_arena_scene)


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
	# A replay can end with the same result key; a new scene starts a new result.
	get_tree().scene_changed.connect(func(): displayed_result = "")
	z_index = 100
	hide()
	# The winner stands in the arena on the right (FollowCamera.show_winner); the result
	# sits in a left column over a shade, as on the main menu.
	add_child(_make_left_shade())
	var panel := PanelContainer.new()
	result_panel = panel
	panel.visibility_changed.connect(_fade_culture_card)
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
	if result_key == displayed_result:
		return
	displayed_result = result_key
	# Hidden while a Phần Lễ played over the previous result.
	result_panel.show()
	# The match captured the mouse for the camera; the result buttons need it back.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in result_actions.get_children():
		result_actions.remove_child(child)
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
			&"FLEE": "thắng thế, đối phương lui sới",
			&"TIME": "khí thế cao hơn khi hết giờ",
			&"LOT": "thắng bốc thăm"
		}.get(SessionState.last_reason, "trận đấu kết thúc")
		result_detail.text = "%s · %s" % [winner, reason]
	_show_culture_card(final_win)

	var retry := _button("CHƠI LẠI TRẬN NÀY")
	retry.pressed.connect(_retry_match)
	result_actions.add_child(retry)
	if won and not final_win:
		var next := _button("TRẬN TIẾP THEO · %s" % _round_name(SessionState.level_id))
		next.pressed.connect(_start_next_match)
		result_actions.add_child(next)
		result_actions.move_child(next, 0)
	var menu := _button("VỀ MENU")
	menu.pressed.connect(_return_to_menu)
	result_actions.add_child(menu)
	if final_win:
		_show_closing_ceremony(retry)
	else:
		result_actions.get_child(0).grab_focus()
		_fade_culture_card()


func _show_culture_card(final_win: bool) -> void:
	var content := result_actions.get_parent() as VBoxContainer
	var previous := content.get_node_or_null("CultureCard")
	if previous != null:
		content.remove_child(previous)
		previous.queue_free()
	var card: Dictionary = {}
	if SessionState.mode == &"SOLO":
		card = CultureCards.next_card(SessionState.culture_cards_seen, final_win)
	var has_card := not card.is_empty()
	result_panel.offset_left = 40.0 if has_card else 64.0
	result_panel.offset_right = 640.0 if has_card else 604.0
	result_panel.offset_top = -290.0 if has_card else -230.0
	result_panel.offset_bottom = 290.0 if has_card else 230.0
	content.add_theme_constant_override("separation", 12 if has_card else 20)
	result_title.add_theme_font_size_override("font_size", GameBalance.get_int("ui_culture_card_result_title_font_size") if has_card else 40)
	result_detail.add_theme_font_size_override("font_size", GameBalance.get_int("ui_culture_card_result_detail_font_size") if has_card else 24)
	if not has_card:
		return
	SessionState.culture_cards_seen.append(StringName(card.id))
	var data := DataFile.load_json("res://data/culture_cards.json")
	var panel := PanelContainer.new()
	panel.name = "CultureCard"
	panel.modulate.a = 0.0
	var style := result_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.set_content_margin_all(12.0)
	style.bg_color = Color("#241D18")
	panel.add_theme_stylebox_override("panel", style)
	content.add_child(panel)
	content.move_child(panel, result_actions.get_index())
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 8)
	panel.add_child(text)
	var heading := "%s · %d/%d" % [data.label, SessionState.culture_cards_seen.size(), data.cards.size()]
	text.add_child(_culture_card_label(heading, "label", Color("#E8BC65")))
	text.add_child(_culture_card_label(card.title, "title", Color("#F2E6CF")))
	text.add_child(_culture_card_label(card.body, "body", Color("#F2E6CF")))


func _culture_card_label(text: String, kind: String, color: Color) -> Label:
	var label := _make_label(text, GameBalance.get_int("ui_culture_card_%s_font_size" % kind), color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _fade_culture_card() -> void:
	if not is_instance_valid(result_actions):
		return
	var card := result_actions.get_parent().get_node_or_null("CultureCard") as PanelContainer
	if card != null and card.is_visible_in_tree() and card.modulate.a == 0.0:
		create_tween().tween_property(card, "modulate:a", 1.0, GameBalance.get_number("ui_culture_card_fade_s"))


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
	_go_to_arena()


func _start_next_match() -> void:
	# level_id already points at the next round; begin_solo() clears the shown result, so it
	# runs only after the rites, or the overlay would rebuild the result underneath them.
	var rites := SessionState.take_rites_before(SessionState.level_id)
	if not rites.is_empty():
		result_panel.hide()
	_play_rites(rites, func():
		SessionState.begin_solo()
		_go_to_arena()
	)


func _return_to_menu() -> void:
	SessionState.return_to_menu()
	displayed_result = ""
	hide()
	get_tree().change_scene_to_file(MENU_SCENE)


func _start_lan() -> void:
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	get_tree().change_scene_to_file(LOBBY_SCENE)
