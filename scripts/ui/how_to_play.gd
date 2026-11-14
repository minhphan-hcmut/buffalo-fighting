class_name HowToPlay
extends Control
## Standalone instructions; the 3D stage is created only when its tab is opened.

signal closed

var tabs: Array[Button] = []
var pages: Array[Control] = []
var selected_tab := 0
var demo: MoveDemo
var panel: PanelContainer


func _ready() -> void:
	name = "HowToPlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#17262EF5")
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
	for title in ["LUẬT CHƠI", "CÁC ĐÒN", "ĐIỀU KHIỂN"]:
		var button := Button.new()
		button.text = title
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := tabs.size()
		button.pressed.connect(select_tab.bind(index))
		button.focus_entered.connect(select_tab.bind(index))
		button.gui_input.connect(_tab_input.bind(index))
		tabs.append(button)
		tab_row.add_child(button)
	var body := Control.new()
	body.name = "Pages"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var rules := VBoxContainer.new()
	rules.name = "Rules"
	rules.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_column_gap"))
	pages.append(rules)
	var moves := Control.new()
	moves.name = "Moves"
	pages.append(moves)
	var controls := ControlsDiagram.new()
	controls.name = "Controls"
	pages.append(controls)
	for page in pages:
		body.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_block(rules, "01 · MỤC TIÊU", "Đưa KHÍ THẾ đối thủ về 0 để đối thủ chịu thua, lui sới. Khí thế không hồi.\nTrận tối đa %d giây; hết giờ bên có khí thế cao hơn thắng. Bằng nhau thì bốc thăm." % GameBalance.get_int("match_duration_s"))
	_block(rules, "02 · GIỮ SỨC", "Đòn đánh và ghìm đều tốn SỨC. Sức tự hồi khi nghỉ; hết sức thì không ghìm được.")
	_block(rules, "03 · MẸO TRÊN SỚI", "Đánh vào sườn hoặc lưng mạnh hơn.\nDồn đối thủ sát rào để đòn đánh mạnh hơn.\nGạt sừng đúng lúc, rồi húc ngay để phản đòn.")
	var back := Button.new()
	back.name = "Back"
	back.text = "QUAY LẠI"
	back.custom_minimum_size = Vector2(GameBalance.get_number("ui_howto_back_width"), GameBalance.get_number("ui_howto_back_height"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	content.add_child(back)
	select_tab(0)
	tabs[0].grab_focus()


## Select a tab, lazily creating the stage and suspending it when hidden.
func select_tab(index: int) -> void:
	selected_tab = wrapi(index, 0, tabs.size())
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == selected_tab)
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


func _tab_input(event: InputEvent, index: int) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		select_tab(index + (1 if event.is_action_pressed("ui_right") else -1))
		tabs[selected_tab].grab_focus()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
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


func _block(parent: Container, heading: String, body: String) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	parent.add_child(block)
	block.add_child(ControlsDiagram.label(heading, "heading", ControlsDiagram.GOLD))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", GameBalance.get_int("ui_howto_body_font_size"))
	text.add_theme_color_override("default_color", ControlsDiagram.PAPER)
	for keyword in ["KHÍ THẾ", "SỨC", "sườn", "lưng", "sát rào", "Gạt sừng", "%d giây" % GameBalance.get_int("match_duration_s"), "bốc thăm"]:
		body = body.replace(keyword, "[b][color=#E8BC65]%s[/color][/b]" % keyword)
	text.text = body
	block.add_child(text)
