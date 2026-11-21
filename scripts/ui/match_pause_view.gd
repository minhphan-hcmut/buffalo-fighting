extends Node
## Scene-owned pause/settings shell, also used by LanResultView.
## Actions are injected; this view never owns a controller or match state.

signal actions_cleared

var root: Control
var pause_overlay: Control
var pause_panel: PanelContainer
var pause_title: Label
var pause_detail: Label
var pause_actions: VBoxContainer
var settings_screen: SettingsScreen
var showing_settings := false
var stats_panel: GridContainer
var actions: Dictionary
var detail_font_size := 16


func setup(ui_root: Control, callbacks: Dictionary) -> void:
	root = ui_root
	actions = callbacks
	ensure_shell()


func ensure_shell() -> void:
	if is_instance_valid(pause_overlay):
		return
	showing_settings = false
	settings_screen = null
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	root.add_child(pause_overlay)
	pause_overlay.tree_exiting.connect(_on_shell_exiting)
	var shade := ColorRect.new()
	shade.name = "PauseShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#1E140CE6")
	pause_overlay.add_child(shade)
	pause_panel = PanelContainer.new()
	pause_overlay.add_child(pause_panel)
	place_panel(Vector2(520, 0))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	pause_panel.add_child(content)
	pause_title = Label.new()
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 30)
	pause_title.add_theme_color_override("font_color", ControlsDiagram.GOLD)
	content.add_child(pause_title)
	pause_detail = Label.new()
	pause_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(pause_detail)
	detail_font_size = pause_detail.get_theme_font_size("font_size")
	pause_actions = VBoxContainer.new()
	pause_actions.add_theme_constant_override("separation", 10)
	content.add_child(pause_actions)


func place_panel(panel_size: Vector2) -> void:
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_panel.offset_left = -panel_size.x * 0.5
	pause_panel.offset_top = -panel_size.y * 0.5
	pause_panel.offset_right = panel_size.x * 0.5
	pause_panel.offset_bottom = panel_size.y * 0.5


func clear_actions() -> void:
	actions_cleared.emit()
	if is_instance_valid(stats_panel):
		stats_panel.get_parent().remove_child(stats_panel)
		stats_panel.queue_free()
	stats_panel = null
	for child in pause_actions.get_children():
		pause_actions.remove_child(child)
		child.queue_free()


func button(text: String, callback: Callable, container: Container = null, tier: StringName = &"SecondaryButton") -> Button:
	var control := Button.new()
	control.theme_type_variation = tier
	control.text = text
	control.custom_minimum_size.y = GameBalance.get_number("ui_action_height")
	control.focus_mode = Control.FOCUS_ALL
	UiMotion.attach(control)
	control.pressed.connect(callback)
	(container if container != null else pause_actions).add_child(control)
	HudText.apply(control)
	return control


func _prepare_pause() -> void:
	ensure_shell()
	close_settings_if_open()
	pause_overlay.show()
	pause_panel.show()
	pause_overlay.get_node("PauseShade").show()
	var result_shade := pause_overlay.get_node_or_null("ResultShade")
	if result_shade != null:
		result_shade.hide()
	place_panel(Vector2(520, 0))
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudText.set_size(pause_title, "font_size", 30)
	HudText.set_size(pause_detail, "font_size", detail_font_size)
	clear_actions()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _focus_first() -> void:
	HudText.apply(pause_title)
	HudText.apply(pause_detail)
	pause_actions.get_child(0).grab_focus()


func show_pause(mode: StringName, training: bool) -> void:
	_prepare_pause()
	pause_title.text = "TẠM DỪNG" if mode == &"SOLO" else "TRẬN LAN ĐANG TẠM DỪNG"
	pause_detail.text = ("Buổi tập đã dừng." if training else "Trận solo đã dừng.") if mode == &"SOLO" else "Hai người chơi đã đồng ý tạm dừng."
	button("GỬI YÊU CẦU TIẾP TỤC" if mode == &"LAN" else "TIẾP TỤC", actions.resume, null, &"PrimaryButton")
	if training:
		button("ĐỔI BÀI TẬP", actions.change_training)
	button("CÀI ĐẶT", show_settings)
	if mode == &"SOLO" and not training:
		button("CHƠI LẠI", actions.restart)
	button("VỀ MENU", actions.leave, null, &"QuietButton")
	_focus_first()


func show_wait(requested_pause: bool) -> void:
	_prepare_pause()
	pause_title.text = "ĐANG CHỜ XÁC NHẬN"
	pause_detail.text = "Yêu cầu tạm dừng đã gửi tới đối phương." if requested_pause else "Yêu cầu tiếp tục trận đã gửi tới đối phương."
	button("CÀI ĐẶT", show_settings, null, &"PrimaryButton")
	button("RỜI TRẬN", actions.leave, null, &"QuietButton")
	_focus_first()


func show_confirmation(peer_id: int, requested_pause: bool) -> void:
	_prepare_pause()
	pause_title.text = Language.t("YÊU CẦU TỪ NGƯỜI CHƠI %d") % peer_id
	pause_detail.text = "Đối phương muốn tạm dừng trận." if requested_pause else "Đối phương muốn tiếp tục trận."
	button("CHẤP NHẬN", actions.answer.bind(true), null, &"PrimaryButton")
	button("TỪ CHỐI", actions.answer.bind(false))
	_focus_first()


func hide_pause() -> void:
	close_settings_if_open()
	if is_instance_valid(pause_overlay):
		pause_overlay.hide()


func show_settings() -> void:
	ensure_shell()
	if showing_settings:
		return
	var opener: Control
	for control in pause_actions.get_children():
		if control is Button and control.text == "CÀI ĐẶT":
			opener = control
	if not is_instance_valid(settings_screen):
		settings_screen = SettingsScreen.new()
		settings_screen.on_sensitivity = actions.sensitivity
		settings_screen.closed.connect(_on_settings_closed)
		pause_overlay.add_child(settings_screen)
	showing_settings = true
	pause_overlay.show()
	pause_overlay.get_node("PauseShade").hide()
	pause_panel.hide()
	settings_screen.open(opener)


func close_settings_if_open() -> bool:
	if not showing_settings or not is_instance_valid(settings_screen):
		return false
	settings_screen.close()
	return true


func _on_settings_closed() -> void:
	showing_settings = false
	if is_instance_valid(pause_overlay) and is_instance_valid(pause_panel):
		HudText.apply(pause_actions)
		pause_overlay.get_node("PauseShade").show()
		pause_panel.show()


func _on_shell_exiting() -> void:
	# SettingsScreen temporarily disables focus outside the modal; restore it even
	# when the entire shell is freed without going through the ordinary close path.
	close_settings_if_open()
	showing_settings = false
	actions_cleared.emit()
	stats_panel = null


func _exit_tree() -> void:
	close_settings_if_open()
	if is_instance_valid(pause_overlay) and not pause_overlay.is_queued_for_deletion():
		pause_overlay.queue_free()
	actions.clear()
