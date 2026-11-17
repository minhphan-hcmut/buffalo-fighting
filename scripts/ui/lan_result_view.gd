extends Node
## LAN result presenter; shares MatchPauseView's shell and owns no match state.

var shell
var request_rematch: Callable
var leave: Callable
var rematch_button: Button
var rematch_note: Label
var lan_result_shown := false


func setup(pause_shell: Node, rematch_action: Callable, leave_action: Callable) -> void:
	shell = pause_shell
	request_rematch = rematch_action
	leave = leave_action
	shell.actions_cleared.connect(_clear_refs)


func _clear_refs() -> void:
	rematch_button = null
	rematch_note = null
	lan_result_shown = false


func show_result(text: String, stats: MatchStats, has_lan: bool, status: Dictionary) -> void:
	shell.ensure_shell()
	shell.close_settings_if_open()
	shell.pause_overlay.show()
	shell.pause_panel.show()
	shell.place_panel(Vector2(GameBalance.get_number("stats_result_width"), 0))
	shell.pause_panel.anchor_left = 0.0
	shell.pause_panel.anchor_right = 0.0
	shell.pause_panel.offset_left = GameBalance.get_number("lan_result_panel_left")
	shell.pause_panel.offset_right = shell.pause_panel.offset_left + GameBalance.get_number("stats_result_width")
	shell.pause_overlay.get_node("PauseShade").hide()
	if not shell.pause_overlay.has_node("ResultShade"):
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, GameBalance.get_number("lan_result_shade_mid"), GameBalance.get_number("lan_result_shade_end")])
		gradient.colors = PackedColorArray([Color("#17120EE6"), Color("#17120EB0"), Color("#17120E00")])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = GameBalance.get_int("lan_result_shade_texture_width")
		texture.height = GameBalance.get_int("lan_result_shade_texture_height")
		var shade := TextureRect.new()
		shade.name = "ResultShade"
		shade.texture = texture
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.pause_overlay.add_child(shade)
		shell.pause_overlay.move_child(shade, 0)
	shell.pause_overlay.get_node("ResultShade").show()
	shell.pause_title.text = "KẾT QUẢ TRẬN LAN"
	HudText.set_size(shell.pause_title, "font_size", GameBalance.get_int("ui_result_title_size"))
	HudText.set_size(shell.pause_detail, "font_size", GameBalance.get_int("ui_result_reason_size"))
	shell.pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shell.pause_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shell.pause_detail.text = text
	shell.clear_actions()
	lan_result_shown = true
	if stats != null:
		shell.stats_panel = stats.create_block()
		var content: Node = shell.pause_actions.get_parent()
		content.add_child(shell.stats_panel)
		content.move_child(shell.stats_panel, shell.pause_actions.get_index())
		HudText.apply(shell.stats_panel)
	if has_lan:
		rematch_note = Label.new()
		rematch_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rematch_note.add_theme_font_size_override("font_size", GameBalance.get_int("stats_font_size"))
		shell.pause_actions.add_child(rematch_note)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", GameBalance.get_int("stats_column_gap"))
		shell.pause_actions.add_child(row)
		rematch_button = shell.button("ĐẤU LẠI", request_rematch, row, &"PrimaryButton")
		rematch_button.name = "RematchButton"
		rematch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var menu: Button = shell.button("VỀ MENU", leave, row, &"QuietButton")
		menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		update_rematch(status)
		(rematch_button if not rematch_button.disabled else menu).grab_focus()
	else:
		shell.button("VỀ MENU", leave, null, &"PrimaryButton").grab_focus()
	for control: Button in shell.pause_actions.find_children("*", "Button", true, false):
		control.custom_minimum_size.y = GameBalance.get_number("ui_result_action_height")
		HudText.set_size(control, "font_size", GameBalance.get_int("ui_result_action_size"))
	HudText.apply(shell.pause_title)
	HudText.apply(shell.pause_detail)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func update_rematch(status: Dictionary) -> void:
	if not is_instance_valid(rematch_button) or status.is_empty():
		return
	var disconnected: bool = status.disconnected
	var local_ready: bool = status.local_ready
	var remote_ready: bool = status.remote_ready
	rematch_button.disabled = disconnected or not status.can_rematch or local_ready
	rematch_button.theme_type_variation = &"SecondaryButton" if rematch_button.disabled else &"PrimaryButton"
	var menu := rematch_button.get_parent().get_child(-1) as Button
	menu.theme_type_variation = &"PrimaryButton" if rematch_button.disabled else &"QuietButton"
	if disconnected:
		rematch_note.text = "Đối phương đã rời trận."
	elif local_ready:
		rematch_note.text = "Đã gửi yêu cầu. Đang chờ đối phương…"
	elif remote_ready:
		rematch_note.text = "Đối phương muốn đấu lại"
	else:
		rematch_note.text = ""
	rematch_button.text = "ĐẤU LẠI" if disconnected else ("ĐANG CHỜ" if local_ready else ("ĐỒNG Ý" if remote_ready else "ĐẤU LẠI"))
	rematch_note.visible = not rematch_note.text.is_empty()
	HudText.apply(rematch_note)
	if rematch_button.disabled and rematch_button.has_focus():
		menu.grab_focus()


func _exit_tree() -> void:
	request_rematch = Callable()
	leave = Callable()
