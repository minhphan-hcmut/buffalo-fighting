class_name HowToPlay
extends Control
## Standalone instructions; the 3D stage is created only when its tab is opened.

signal closed

var tabs: Array[Button] = []
var pages: Array[Control] = []
var selected_tab := 0
var demo: MoveDemo
var panel: PanelContainer
var notebook: FestivalNotebook


func _ready() -> void:
	name = "HowToPlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#17120EF0")
	add_child(shade)
	panel = PanelContainer.new()
	panel.name = "Panel"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var half := Vector2(GameBalance.get_number("ui_howto_panel_width"), GameBalance.get_number("ui_howto_panel_height")) * 0.5
	panel.offset_left = -half.x
	panel.offset_right = half.x
	panel.offset_top = -half.y
	panel.offset_bottom = half.y
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_gap"))
	panel.add_child(content)
	content.add_child(ControlsDiagram.label("CÁCH CHƠI", "title", ControlsDiagram.GOLD))
	var tab_row := HBoxContainer.new()
	tab_row.name = "Tabs"
	tab_row.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	content.add_child(tab_row)
	var group := ButtonGroup.new()
	for title in ["LUẬT CHƠI", "CÁC ĐÒN", "ĐIỀU KHIỂN", "SỔ TAY"]:
		var button := Button.new()
		button.theme_type_variation = &"QuietButton"
		button.text = title
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := tabs.size()
		button.pressed.connect(select_tab.bind(index))
		button.gui_input.connect(_tab_input.bind(index))
		tabs.append(button)
		tab_row.add_child(button)
	var body := Control.new()
	body.name = "Pages"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var rules := HBoxContainer.new()
	rules.name = "Rules"
	rules.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_column_gap"))
	pages.append(rules)
	var moves := Control.new()
	moves.name = "Moves"
	pages.append(moves)
	var controls := ControlsDiagram.new()
	controls.name = "Controls"
	pages.append(controls)
	var collection := Control.new()
	collection.name = "NotebookPage"
	pages.append(collection)
	for page in pages:
		body.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in 3:
		rules.add_child(HowtoDiagrams.create_card(index))
	var back := Button.new()
	back.theme_type_variation = &"QuietButton"
	UiMotion.attach(back)
	back.name = "Back"
	back.text = "QUAY LẠI"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.custom_minimum_size = Vector2(GameBalance.get_number("ui_howto_back_width"), GameBalance.get_number("ui_howto_back_height"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close)
	content.add_child(back)
	select_tab(0)
	tabs[0].grab_focus()


## Select a tab, lazily creating the stage and suspending it when hidden.
func select_tab(index: int) -> void:
	selected_tab = wrapi(index, 0, tabs.size())
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == selected_tab)
		tabs[i].theme_type_variation = &"PrimaryTab" if i == selected_tab else &"QuietTab"
		pages[i].visible = i == selected_tab
	if selected_tab == 1 and demo == null:
		demo = MoveDemo.new()
		demo.tab_step_requested.connect(func(direction: int):
			select_tab(selected_tab + direction)
			tabs[selected_tab].grab_focus()
		)
		pages[1].add_child(demo)
		demo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if demo != null:
		demo.set_active(selected_tab == 1)
	if selected_tab == 3:
		if notebook == null:
			notebook = FestivalNotebook.new()
			pages[3].add_child(notebook)
			notebook.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		else:
			notebook.refresh()
	_link_focus()


## Only the selected page participates in Tab/Shift+Tab; arrows or activation switch pages.
func _link_focus() -> void:
	var back := panel.find_child("Back", true, false) as Button
	back.focus_next = back.get_path_to(tabs[0])
	tabs[0].focus_previous = tabs[0].get_path_to(back)
	for index in tabs.size():
		var fields: Array[Control] = []
		if index == selected_tab:
			for field: Control in pages[index].find_children("*", "Control", true, false):
				if field.focus_mode == Control.FOCUS_ALL:
					fields.append(field)
		var following: Control = tabs[index + 1] if index + 1 < tabs.size() else back
		tabs[index].focus_next = tabs[index].get_path_to(fields[0] if not fields.is_empty() else following)
		following.focus_previous = following.get_path_to(fields[-1] if not fields.is_empty() else tabs[index])
		for item in fields.size():
			fields[item].focus_previous = fields[item].get_path_to(fields[item - 1] if item > 0 else tabs[index])
			fields[item].focus_next = fields[item].get_path_to(fields[item + 1] if item + 1 < fields.size() else following)


func _tab_input(event: InputEvent, index: int) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		select_tab(index + (1 if event.is_action_pressed("ui_right") else -1))
		tabs[selected_tab].grab_focus()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Release the stage and return control to the menu.
func close() -> void:
	hide()
	if demo != null:
		demo.set_active(false)
	closed.emit()
	queue_free()
