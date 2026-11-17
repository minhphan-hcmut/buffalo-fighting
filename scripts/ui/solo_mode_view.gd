class_name SoloModeView
extends Control
## Scene-owned mode pages. Callbacks are intents; this view never begins a session.

var page: Control
var _season: Callable
var _free_play: Callable
var _training: Callable
var _unlimited: Callable
var _back: Callable


func setup(season: Callable, free_play: Callable, training: Callable, unlimited: Callable, back: Callable) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_season = season
	_free_play = free_play
	_training = training
	_unlimited = unlimited
	_back = back


func close() -> void:
	if is_instance_valid(page):
		page.get_parent().remove_child(page)
		page.queue_free()
		page = null


func _exit_tree() -> void:
	# Child pages are freed automatically; do not mutate the tree during teardown.
	page = null


func _page(title: String) -> VBoxContainer:
	close()
	page = Control.new()
	page.name = "SoloPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var dim := ColorRect.new()
	dim.color = Color("#17120EB0")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = GameBalance.get_number("ui_free_play_page_width")
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", Color("#E8BC65"))
	rows.add_child(heading)
	return rows


func _button(text: String, tier: StringName = &"SecondaryButton") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = tier
	button.custom_minimum_size = Vector2(GameBalance.get_number("ui_action_width"), GameBalance.get_number("ui_action_height"))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	UiMotion.attach(button)
	return button


func _add_back(rows: VBoxContainer, callback: Callable) -> void:
	var back := _button("QUAY LẠI", &"QuietButton")
	back.name = "SoloBack"
	back.pressed.connect(callback)
	rows.add_child(back)
	(rows.get_child(1) as Button).grab_focus()


func show_chooser() -> void:
	var rows := _page("SOLO")
	(rows.get_parent() as PanelContainer).custom_minimum_size.x = 0.0
	var season := _button("MÙA HỘI", &"PrimaryButton")
	season.name = "SeasonButton"
	season.pressed.connect(_season)
	rows.add_child(season)
	var free := _button("ĐẤU TỰ DO")
	free.name = "FreePlayButton"
	free.pressed.connect(show_free_play)
	rows.add_child(free)
	var training_button := _button("SÂN TẬP")
	training_button.name = "TrainingButton"
	training_button.pressed.connect(show_training)
	rows.add_child(training_button)
	_add_back(rows, _back)


func show_free_play() -> void:
	var rows := _page("ĐẤU TỰ DO")
	var levels := DataFile.load_json("res://data/levels.json")
	for level: StringName in SessionState.SOLO_LEVELS:
		var data: Dictionary = levels[level]
		var button := _button("%s · %s\n%s · %s" % [data.title.to_upper(), levels.difficulty_labels[data.ai_profile], data.opponent_number, data.opponent_giap])
		if level == SessionState.SOLO_LEVELS[0]:
			button.theme_type_variation = &"PrimaryButton"
		button.name = String(level)
		button.custom_minimum_size = Vector2(640, GameBalance.get_number("ui_free_play_row_height"))
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_free_play.bind(level))
		rows.add_child(button)
	_add_back(rows, show_chooser)


func show_training() -> void:
	var rows := _page("SÂN TẬP")
	rows.add_theme_constant_override("separation", GameBalance.get_int("training_menu_gap"))
	var unlimited := CheckButton.new()
	unlimited.name = "UnlimitedStamina"
	unlimited.text = "Sức vô hạn"
	unlimited.add_theme_font_size_override("font_size", GameBalance.get_int("training_menu_font_size"))
	SettingsControls.style_toggle(unlimited)
	unlimited.button_pressed = SessionState.training_unlimited_stamina
	unlimited.toggled.connect(_unlimited)
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
		button.pressed.connect(_training.bind(StringName(drill.id)))
		rows.add_child(button)
	_select_training_row(training_rows[0], training_rows)
	rows.add_child(unlimited)
	_add_back(rows, show_chooser)


func _select_training_row(selected: Button, rows: Array[Button]) -> void:
	for button in rows:
		button.theme_type_variation = &"PrimaryRow" if button == selected else &"QuietButton"
		button.add_theme_color_override("font_color", ControlsDiagram.GOLD if button == selected else ControlsDiagram.PAPER)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := SettingsControls.row_style(button == selected or state in ["hover", "pressed", "focus"])
			style.content_margin_top = GameBalance.get_number("training_menu_name_top")
			style.content_margin_bottom = GameBalance.get_number("training_menu_caption_space")
			button.add_theme_stylebox_override(state, style)
