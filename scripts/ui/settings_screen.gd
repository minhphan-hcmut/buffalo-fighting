class_name SettingsScreen
extends Control
## The same modal settings surface in the menu and in a paused match.

signal closed

const TAB_NAMES := ["Âm thanh", "Điều khiển", "Camera", "Đồ họa", "Hiệu ứng"]

var panel: PanelContainer
var tabs: Array[Button] = []
var pages: Array[VBoxContainer] = []
var scrolls: Array[ScrollContainer] = []
var selected_tab := 0
var reset_button: Button
var done: Button
var opener: Control
var covered: Array[Control] = []
var on_sensitivity := Callable()


func _ready() -> void:
	name = "SettingsScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#1E1914B0")
	add_child(shade)
	panel = PanelContainer.new()
	panel.name = "Panel"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var half := Vector2(GameBalance.get_number("settings_panel_width"), GameBalance.get_number("settings_panel_height")) * 0.5
	panel.offset_left = -half.x
	panel.offset_right = half.x
	panel.offset_top = -half.y
	panel.offset_bottom = half.y
	var style := StyleBoxFlat.new()
	style.bg_color = SettingsControls.PANEL
	style.border_color = ControlsDiagram.GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(GameBalance.get_number("settings_padding"))
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", GameBalance.get_int("settings_gap"))
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = GameBalance.get_number("settings_header_height")
	content.add_child(header)
	var title := Label.new()
	title.text = "CÀI ĐẶT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", GameBalance.get_int("settings_title_size"))
	title.add_theme_color_override("font_color", ControlsDiagram.GOLD)
	header.add_child(title)
	var saved := Label.new()
	saved.text = "Tự động lưu"
	saved.add_theme_font_size_override("font_size", GameBalance.get_int("settings_hint_size"))
	saved.add_theme_color_override("font_color", SettingsControls.MUTED)
	header.add_child(saved)
	content.add_child(_divider())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", GameBalance.get_int("settings_gap"))
	content.add_child(body)
	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = GameBalance.get_number("settings_rail_width")
	rail.add_theme_constant_override("separation", 0)
	body.add_child(rail)
	var page_holder := Control.new()
	page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(page_holder)
	for index in TAB_NAMES.size():
		var tab := Button.new()
		tab.text = TAB_NAMES[index]
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size.y = GameBalance.get_number("settings_row_height")
		SettingsControls.quiet_button(tab)
		tab.pressed.connect(select_tab.bind(index))
		rail.add_child(tab)
		tabs.append(tab)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
		scroll.follow_focus = true
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page_holder.add_child(scroll)
		scrolls.append(scroll)
		var rows := VBoxContainer.new()
		rows.name = "Tab%d" % index
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		SettingsControls.populate(rows, index, on_sensitivity)
		pages.append(rows)
		scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	content.add_child(_divider())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", GameBalance.get_int("settings_gap"))
	content.add_child(footer)
	reset_button = Button.new()
	reset_button.name = "Reset"
	reset_button.text = "Khôi phục mặc định"
	SettingsControls.quiet_button(reset_button)
	reset_button.pressed.connect(func(): SettingsControls.reset_tab(pages[selected_tab], selected_tab))
	footer.add_child(reset_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	done = Button.new()
	done.theme_type_variation = &"PrimaryButton"
	done.name = "Done"
	done.text = "XONG"
	done.custom_minimum_size = Vector2(GameBalance.get_number("settings_done_width"), GameBalance.get_number("settings_footer_height"))
	done.pressed.connect(close)
	footer.add_child(done)
	hide()


func _divider() -> HSeparator:
	var separator := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(SettingsControls.MUTED, GameBalance.get_number("settings_divider_alpha"))
	separator.add_theme_stylebox_override("separator", style)
	return separator


func open(from: Control) -> void:
	opener = from
	if visible:
		return
	covered.clear()
	for control: Control in get_tree().root.find_children("*", "Control", true, false):
		if not is_ancestor_of(control) and control != self and control.focus_mode == Control.FOCUS_ALL:
			covered.append(control)
			control.focus_mode = Control.FOCUS_NONE
	show()
	select_tab(0)


func select_tab(index: int) -> void:
	selected_tab = wrapi(index, 0, tabs.size())
	for i in tabs.size():
		scrolls[i].visible = i == selected_tab
		tabs[i].add_theme_stylebox_override("normal", SettingsControls.row_style(i == selected_tab))
		tabs[i].add_theme_color_override("font_color", ControlsDiagram.GOLD if i == selected_tab else SettingsControls.MUTED)
	# Explicit cycle excludes every hidden tab's rows and any controls behind the modal.
	var stops: Array[Control] = []
	stops.append_array(pages[selected_tab].get_children())
	stops.append(reset_button)
	stops.append(done)
	stops.append_array(tabs)
	for i in stops.size():
		stops[i].focus_next = stops[i].get_path_to(stops[(i + 1) % stops.size()])
		stops[i].focus_previous = stops[i].get_path_to(stops[wrapi(i - 1, 0, stops.size())])
		stops[i].focus_neighbor_bottom = stops[i].focus_next
		stops[i].focus_neighbor_top = stops[i].focus_previous
		stops[i].focus_neighbor_left = stops[i].get_path_to(stops[i])
		stops[i].focus_neighbor_right = stops[i].get_path_to(stops[i])
	scrolls[selected_tab].scroll_vertical = 0
	stops[0].grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	for control in covered:
		if is_instance_valid(control):
			control.focus_mode = Control.FOCUS_ALL
	covered.clear()
	closed.emit()
	if is_instance_valid(opener) and opener.is_visible_in_tree():
		opener.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var direction := 0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			direction = -1
		elif event.keycode == KEY_E:
			direction = 1
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			direction = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			direction = 1
	if direction != 0:
		select_tab(selected_tab + direction)
		get_viewport().set_input_as_handled()
