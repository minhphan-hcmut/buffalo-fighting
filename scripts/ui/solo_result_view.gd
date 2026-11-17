class_name SoloResultView
extends Control
## Result nodes and animations only; sequencing and persistence are injected intents.

signal card_visible(card_id: StringName)

var result_title: Label
var result_detail: Label
var result_actions: VBoxContainer
var result_panel: PanelContainer
var result_stage: Control
var displayed_result := ""
var result_tween: Tween
var _card_tween: Tween
var _retry: Callable
var _next: Callable
var _menu: Callable
var _change: Callable
var _closing: Callable
var _result_data: Callable
var _select_card: Callable


func setup(retry: Callable, next: Callable, menu: Callable, change: Callable, closing: Callable, result_data: Callable, select_card: Callable) -> void:
	_retry = retry
	_next = next
	_menu = menu
	_change = change
	_closing = closing
	_result_data = result_data
	_select_card = select_card
	_build_session_overlay()


func _build_session_overlay() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A replay can end with the same result key; a new scene starts a new result.
	get_tree().scene_changed.connect(reset_result)
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

	var data: Dictionary = _result_data.call()
	var level: StringName = data.level
	var won: bool = data.won
	var final_win: bool = data.final_win
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
		}.get(data.reason, "trận đấu kết thúc")
		result_detail.text = "%s · %s" % [winner, reason]
	_render_culture_card(data.culture)
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

	var retry := _button("CHƠI LẠI" if data.free_play else "CHƠI LẠI TRẬN NÀY", &"PrimaryButton")
	retry.pressed.connect(_retry)
	result_actions.add_child(retry)
	if data.free_play:
		var change := _button("ĐỔI TRẬN")
		change.pressed.connect(_change)
		result_actions.add_child(change)
	elif won and not final_win:
		retry.theme_type_variation = &"SecondaryButton"
		var next := _button("TRẬN TIẾP THEO · %s" % _round_name(data.next_level), &"PrimaryButton")
		next.pressed.connect(_next)
		result_actions.add_child(next)
		result_actions.move_child(next, 0)
	var menu := _button("VỀ MENU", &"QuietButton")
	menu.pressed.connect(_menu)
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
		result_panel.hide()
		_closing.call(reveal_result.bind(retry))
	else:
		result_actions.get_child(0).grab_focus()
		_fade_culture_card()
		result_tween = UiMotion.enter_result(result_stage, result_actions)


func _show_culture_card(final_win: bool) -> void:
	_render_culture_card(_select_card.call(final_win))


func _render_culture_card(selection: Dictionary) -> void:
	if _card_tween != null:
		_card_tween.kill()
	var content := result_actions.get_parent() as VBoxContainer
	var previous := content.get_node_or_null("CultureCard")
	if previous != null:
		content.remove_child(previous)
		previous.queue_free()
	var card: Dictionary = selection.card
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
	var heading := "%s · %d/%d" % [data.label, selection.count, data.cards.size()]
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
		if card.get_meta("awarded", false):
			return
		card.set_meta("awarded", true)
		card_visible.emit(card.get_meta("card_id"))
		_card_tween = create_tween()
		_card_tween.tween_property(card, "modulate:a", 1.0, GameBalance.get_number("ui_culture_card_fade_s"))


## GDD Bảng 17 closing rite: shown once over the final result, then the result actions return.
func reveal_result(focus_after: Button) -> void:
	if not is_inside_tree() or not is_instance_valid(focus_after):
		return
	result_panel.show()
	focus_after.grab_focus()
	result_tween = UiMotion.enter_result(result_stage, result_actions)


func reset_result() -> void:
	displayed_result = ""


func _exit_tree() -> void:
	if result_tween != null:
		result_tween.kill()
	if _card_tween != null:
		_card_tween.kill()


func _round_name(level: StringName) -> String:
	var levels := DataFile.load_json("res://data/levels.json")
	return String(levels.get(String(level), {}).get("title", "Mùa hội")).to_upper()


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
