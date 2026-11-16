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
var result_stage: Control
var displayed_result := ""
var result_tween: Tween
var menu_settings_layer: SettingsScreen
var solo_page: Control
static var return_to_free_play := false
static var return_to_training := false
# The arena (buffalo model, grass textures) loads on a thread while the menu and the rites
# are on screen, so entering a match no longer freezes for ~1.5 s. Kept for retries.
static var _arena_scene: PackedScene


func _ready() -> void:
	MatchInput.configure_ui()
	if get_meta("session_overlay", false):
		process_mode = Node.PROCESS_MODE_ALWAYS
		_build_session_overlay()
		return
	# The saved FPS limit, render scale and model detail apply from the menu on, not only in a match.
	GraphicsQuality.apply_live()
	(get_node("/root/GameAudio") as FestivalAudio).play_music("music_festival_loop", true)
	_prefetch_arena()
	_build_main_menu()
	if return_to_training:
		return_to_training = false
		_show_training()
	elif return_to_free_play:
		return_to_free_play = false
		_show_free_play()


func _process(_delta: float) -> void:
	if not get_meta("session_overlay", false):
		return
	var scene := get_tree().current_scene
	if not scene is MatchController:
		hide()
		return
	var is_solo_result: bool = SessionState.mode == &"SOLO" and scene.get("phase") == &"RESULT" and scene.get("result_ready")
	visible = is_solo_result
	scene.hud.visible = not is_solo_result and (scene.replay == null or not scene.replay.active)
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
	menu_layout.offset_left = GameBalance.get_number("ui_menu_left")
	menu_layout.offset_right = menu_layout.offset_left + GameBalance.get_number("ui_menu_width")
	menu_layout.offset_top = -GameBalance.get_number("ui_menu_half_height")
	menu_layout.offset_bottom = GameBalance.get_number("ui_menu_half_height")
	menu_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_layout.add_theme_constant_override("separation", GameBalance.get_int("ui_menu_gap"))
	add_child(menu_layout)
	var title := _make_label("CHỌI TRÂU", 72, Color("#E8BC65"))
	title.add_theme_color_override("font_outline_color", Color("#241D18"))
	title.add_theme_constant_override("outline_size", 10)
	menu_layout.add_child(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var subtitle := _make_label("ĐẤU TRƯỜNG LỄ HỘI", 24, Color("#F2E6CF"))
	menu_layout.add_child(subtitle)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var solo := _button("SOLO · MÙA HỘI")
	solo.theme_type_variation = &"MenuPrimary"
	solo.name = "SoloButton"
	solo.pressed.connect(_show_solo_chooser)
	menu_layout.add_child(solo)
	var lan := _button("LAN")
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
	for item in [solo, lan, howto, settings, quit]:
		item.theme_type_variation = &"MenuPrimary" if item == solo else &"MenuSecondary"
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.set_meta("menu_item", true)
	quit.theme_type_variation = &"QuietButton"
	var footer := _make_label("Mùa hội: Vòng loại · Vòng hai · Tứ kết · Bán kết · Chung kết", GameBalance.get_int("ui_menu_footer_size"), SettingsControls.MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_layout.add_child(footer)
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
	GraphicsQuality.apply_viewport(viewport)
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
	if not is_instance_valid(menu_settings_layer):
		menu_settings_layer = SettingsScreen.new()
		menu_settings_layer.closed.connect(func(): menu_layout.show())
		add_child(menu_settings_layer)
	menu_layout.hide()
	menu_settings_layer.open(menu_layout.get_node("SettingsButton"))


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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(menu_settings_layer) and menu_settings_layer.visible:
		menu_settings_layer.close()
	elif is_instance_valid(solo_page):
		(solo_page.find_child("SoloBack", true, false) as Button).pressed.emit()
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


func _button(text: String, tier: StringName = &"SecondaryButton") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = tier
	button.custom_minimum_size = Vector2(GameBalance.get_number("ui_action_width"), GameBalance.get_number("ui_action_height"))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	UiMotion.attach(button)
	return button


func _start_solo() -> void:
	_close_solo_page()
	var rites: Array[StringName] = []
	if SessionState.begin_solo():
		rites.append(&"opening")
	rites.append_array(SessionState.take_rites_before(SessionState.level_id))
	if rites.is_empty():
		_enter_arena()
	else:
		menu_layout.hide()
		_play_rites(rites, _enter_arena)


func _close_solo_page() -> void:
	if is_instance_valid(solo_page):
		remove_child(solo_page)
		solo_page.queue_free()
		solo_page = null


func _solo_page(title: String) -> VBoxContainer:
	_close_solo_page()
	menu_layout.hide()
	solo_page = Control.new()
	solo_page.name = "SoloPage"
	solo_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(solo_page)
	var dim := ColorRect.new()
	dim.color = Color("#17120EB0")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	solo_page.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	solo_page.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = GameBalance.get_number("ui_free_play_page_width")
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	rows.add_child(_make_label(title, 36, Color("#E8BC65")))
	return rows


func _solo_back(rows: VBoxContainer, callback: Callable) -> void:
	var back := _button("QUAY LẠI", &"QuietButton")
	back.name = "SoloBack"
	back.pressed.connect(callback)
	rows.add_child(back)
	(rows.get_child(1) as Button).grab_focus()


func _show_solo_chooser() -> void:
	var rows := _solo_page("SOLO")
	(rows.get_parent() as PanelContainer).custom_minimum_size.x = 0.0
	var season := _button("MÙA HỘI", &"PrimaryButton")
	season.name = "SeasonButton"
	season.pressed.connect(_start_solo)
	rows.add_child(season)
	var free := _button("ĐẤU TỰ DO")
	free.name = "FreePlayButton"
	free.pressed.connect(_show_free_play)
	rows.add_child(free)
	var training_button := _button("SÂN TẬP")
	training_button.name = "TrainingButton"
	training_button.pressed.connect(_show_training)
	rows.add_child(training_button)
	_solo_back(rows, func():
		_close_solo_page()
		menu_layout.show()
		menu_layout.get_node("SoloButton").grab_focus()
	)


func _show_free_play() -> void:
	var rows := _solo_page("ĐẤU TỰ DO")
	var levels := DataFile.load_json("res://data/levels.json")
	for level: StringName in SessionState.SOLO_LEVELS:
		var data: Dictionary = levels[level]
		var button := _button("%s · %s\n%s · %s" % [data.title.to_upper(), levels.difficulty_labels[data.ai_profile], data.opponent_number, data.opponent_giap])
		if level == SessionState.SOLO_LEVELS[0]:
			button.theme_type_variation = &"PrimaryButton"
		button.name = String(level)
		button.custom_minimum_size = Vector2(640, GameBalance.get_number("ui_free_play_row_height"))
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(func():
			SessionState.begin_free_play(level)
			_close_solo_page()
			_enter_arena()
		)
		rows.add_child(button)
	_solo_back(rows, _show_solo_chooser)


func _show_training() -> void:
	var rows := _solo_page("SÂN TẬP")
	rows.add_theme_constant_override("separation", GameBalance.get_int("training_menu_gap"))
	var unlimited := CheckButton.new()
	unlimited.name = "UnlimitedStamina"
	unlimited.text = "Sức vô hạn"
	unlimited.add_theme_font_size_override("font_size", GameBalance.get_int("training_menu_font_size"))
	SettingsControls.style_toggle(unlimited)
	unlimited.button_pressed = SessionState.training_unlimited_stamina
	unlimited.toggled.connect(func(enabled: bool):
		SessionState.training_unlimited_stamina = enabled
		SessionState.save_settings()
	)
	var training_rows: Array[Button] = []
	for drill: Dictionary in DataFile.load_json("res://data/training.json").drills:
		var keys: Array[String] = []
		for move: Dictionary in MoveDemo.MOVES:
			if drill.moves.has(String(move.id)):
				keys.append(move.keys)
		var button := Button.new()
		button.text = drill.name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.name = drill.id
		button.custom_minimum_size = Vector2(GameBalance.get_number("training_menu_row_width"), GameBalance.get_number("training_menu_row_height"))
		button.add_theme_font_size_override("font_size", GameBalance.get_int("training_menu_name_size"))
		button.focus_entered.connect(_select_training_row.bind(button, training_rows))
		training_rows.append(button)
		var key_row := HBoxContainer.new()
		key_row.name = "Keys"
		key_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		key_row.offset_left = GameBalance.get_number("training_menu_name_width")
		key_row.offset_right = -GameBalance.get_number("settings_gap")
		key_row.offset_top = GameBalance.get_number("training_menu_key_top")
		key_row.alignment = BoxContainer.ALIGNMENT_END
		button.add_child(key_row)
		for text in keys:
			var cap := ControlsDiagram.keycap(text, false)
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cap.custom_minimum_size.y = GameBalance.get_number("training_menu_key_height")
			var cap_style := cap.get_theme_stylebox("panel") as StyleBoxFlat
			cap_style.content_margin_top = GameBalance.get_number("training_menu_key_padding")
			cap_style.content_margin_bottom = cap_style.content_margin_top
			var cap_text := cap.get_child(0) as Label
			cap_text.add_theme_font_size_override("font_size", GameBalance.get_int("training_menu_key_size"))
			cap_text.add_theme_color_override("font_color", SettingsControls.MUTED)
			key_row.add_child(cap)
		var caption := Label.new()
		caption.name = "Description"
		caption.text = drill.goal
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_left = GameBalance.get_number("settings_gap")
		caption.offset_right = -GameBalance.get_number("settings_gap")
		caption.offset_top = -GameBalance.get_number("training_menu_caption_space")
		caption.offset_bottom = -GameBalance.get_number("training_menu_caption_bottom")
		caption.add_theme_font_size_override("font_size", GameBalance.get_int("training_menu_caption_size"))
		caption.add_theme_color_override("font_color", SettingsControls.MUTED)
		button.add_child(caption)
		button.pressed.connect(func():
			SessionState.begin_training(StringName(drill.id))
			_close_solo_page()
			_enter_arena()
		)
		rows.add_child(button)
	_select_training_row(training_rows[0], training_rows)
	rows.add_child(unlimited)
	_solo_back(rows, _show_solo_chooser)


func _select_training_row(selected: Button, rows: Array[Button]) -> void:
	for button in rows:
		button.theme_type_variation = &"PrimaryRow" if button == selected else &"QuietButton"
		button.add_theme_color_override("font_color", ControlsDiagram.GOLD if button == selected else ControlsDiagram.PAPER)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := SettingsControls.row_style(button == selected or state in ["hover", "pressed", "focus"])
			style.content_margin_top = GameBalance.get_number("training_menu_name_top")
			style.content_margin_bottom = GameBalance.get_number("training_menu_caption_space")
			button.add_theme_stylebox_override(state, style)


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
	var tree := Engine.get_main_loop() as SceneTree
	if _arena_scene == null and not tree.process_frame.is_connected(_finish_prefetch):
		tree.process_frame.connect(_finish_prefetch)


## Collect the request even when the menu leaves for LAN; no coroutine owns a freed menu.
static func _finish_prefetch() -> void:
	var status := ResourceLoader.load_threaded_get_status(ARENA_SCENE)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_arena_scene = ResourceLoader.load_threaded_get(ARENA_SCENE)
	(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_finish_prefetch)


func _go_to_arena() -> void:
	if _arena_scene == null:
		var requested := ResourceLoader.load_threaded_get_status(ARENA_SCENE) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		# load_threaded_get() waits for a load still in flight.
		_arena_scene = ResourceLoader.load_threaded_get(ARENA_SCENE) if requested else load(ARENA_SCENE)
	UiMotion.change_scene(get_tree(), _arena_scene)


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
	var panel_style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.set_content_margin_all(GameBalance.get_number("ui_result_padding"))
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.visibility_changed.connect(_fade_culture_card.call_deferred)
	# Move a plain parent so wrapped labels never change the panel's minimum size mid-tween.
	result_stage = Control.new()
	result_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result_stage)
	result_stage.add_child(panel)
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
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(result_title)
	result_detail = _make_label("", 24, Color("#F2E6CF"))
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(result_detail)
	result_actions = VBoxContainer.new()
	result_actions.add_theme_constant_override("separation", 12)
	content.add_child(result_actions)


func _show_result(result_key: String) -> void:
	if result_key == displayed_result:
		return
	displayed_result = result_key
	if result_tween != null:
		result_tween.kill()
	result_stage.position = Vector2.ZERO
	# Hidden while a Phần Lễ played over the previous result.
	result_panel.show()
	# The match captured the mouse for the camera; the result buttons need it back.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in result_actions.get_children():
		result_actions.remove_child(child)
		child.queue_free()

	var level := SessionState.last_match_level
	var won := SessionState.last_winner == 1
	var final_win := won and not SessionState.free_play and level == SessionState.SOLO_LEVELS[-1]
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
	var content := result_actions.get_parent()
	var old_stats := content.get_node_or_null("MatchStats")
	if old_stats != null:
		content.remove_child(old_stats)
		old_stats.queue_free()
	var arena := get_tree().current_scene as MatchController
	if arena != null and arena.hud.stats != null:
		result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		var block: GridContainer = arena.hud.stats.create_block()
		content.add_child(block)
		content.move_child(block, result_detail.get_index() + 1)
		content.add_theme_constant_override("separation", GameBalance.get_int("stats_result_gap"))
		result_panel.offset_right = result_panel.offset_left + GameBalance.get_number("stats_result_width")
		result_panel.offset_top = -GameBalance.get_number("stats_result_half_height")
		result_panel.offset_bottom = GameBalance.get_number("stats_result_half_height")

	var retry := _button("CHƠI LẠI" if SessionState.free_play else "CHƠI LẠI TRẬN NÀY", &"PrimaryButton")
	retry.pressed.connect(_retry_match)
	result_actions.add_child(retry)
	if SessionState.free_play:
		var change := _button("ĐỔI TRẬN")
		change.pressed.connect(_change_free_play_match)
		result_actions.add_child(change)
	elif won and not final_win:
		retry.theme_type_variation = &"SecondaryButton"
		var next := _button("TRẬN TIẾP THEO · %s" % _round_name(SessionState.level_id), &"PrimaryButton")
		next.pressed.connect(_start_next_match)
		result_actions.add_child(next)
		result_actions.move_child(next, 0)
	var menu := _button("VỀ MENU", &"QuietButton")
	menu.pressed.connect(_return_to_menu)
	result_actions.add_child(menu)
	result_actions.add_theme_constant_override("separation", GameBalance.get_int("ui_result_action_gap"))
	for button: Button in result_actions.get_children():
		button.custom_minimum_size.y = GameBalance.get_number("ui_result_action_height")
		button.add_theme_font_size_override("font_size", GameBalance.get_int("ui_result_action_size"))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			style.content_margin_top = GameBalance.get_number("ui_result_action_padding")
			style.content_margin_bottom = style.content_margin_top
			button.add_theme_stylebox_override(state, style)
	HudText.apply(result_panel)
	if final_win:
		_show_closing_ceremony(retry)
	else:
		result_actions.get_child(0).grab_focus()
		_fade_culture_card()
		result_tween = UiMotion.enter_result(result_stage, result_actions)


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
	HudText.set_size(result_title, "font_size", GameBalance.get_int("ui_result_title_size"))
	HudText.set_size(result_detail, "font_size", GameBalance.get_int("ui_result_reason_size"))
	if not has_card:
		return
	SessionState.culture_cards_seen.append(StringName(card.id))
	var data := DataFile.load_json("res://data/culture_cards.json")
	var panel := PanelContainer.new()
	panel.name = "CultureCard"
	panel.set_meta("card_id", StringName(card.id))
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
	if card != null and result_panel.is_visible_in_tree() and card.is_visible_in_tree() and card.modulate.a == 0.0:
		CultureCards.mark_shown(card.get_meta("card_id"))
		create_tween().tween_property(card, "modulate:a", 1.0, GameBalance.get_number("ui_culture_card_fade_s"))


## GDD Bảng 17 closing rite: shown once over the final result, then the result actions return.
func _show_closing_ceremony(focus_after: Button) -> void:
	result_panel.hide()
	var view := CeremonyView.create(&"closing")
	view.finished.connect(func():
		view.queue_free()
		result_panel.show()
		focus_after.grab_focus()
		result_tween = UiMotion.enter_result(result_stage, result_actions)
	)
	add_child(view)


func _round_name(level: StringName) -> String:
	var levels := DataFile.load_json("res://data/levels.json")
	return String(levels.get(String(level), {}).get("title", "Mùa hội")).to_upper()


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
	UiMotion.change_scene(get_tree(), load(MENU_SCENE))


func _change_free_play_match() -> void:
	return_to_free_play = true
	_return_to_menu()


func _start_lan() -> void:
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	get_tree().change_scene_to_file(LOBBY_SCENE)
