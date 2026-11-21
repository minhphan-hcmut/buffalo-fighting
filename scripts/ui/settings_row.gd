class_name SettingsRow
extends PanelContainer
## One focus stop per setting, including its label and fixed-width control column.

var control: Control
var column: HBoxContainer
var hint_label: Label
var hovered := false


func _init(key: String = "", title: String = "", widget: Control = null, hint: String = "") -> void:
	name = key + "Row"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = GameBalance.get_number("settings_row_height")
	control = widget
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", GameBalance.get_int("settings_gap"))
	add_child(line)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	labels.add_theme_constant_override("separation", 0)
	line.add_child(labels)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", GameBalance.get_int("settings_label_size"))
	labels.add_child(label)
	if not hint.is_empty():
		hint_label = Label.new()
		hint_label.text = hint
		hint_label.add_theme_font_size_override("font_size", GameBalance.get_int("settings_hint_size"))
		hint_label.add_theme_color_override("font_color", SettingsControls.MUTED)
		labels.add_child(hint_label)
	column = HBoxContainer.new()
	column.name = "ControlColumn"
	column.custom_minimum_size.x = GameBalance.get_number("settings_control_width")
	column.alignment = BoxContainer.ALIGNMENT_END
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", GameBalance.get_int("settings_gap"))
	line.add_child(column)
	if control != null:
		control.name = key
		control.focus_mode = Control.FOCUS_NONE
		control.custom_minimum_size.y = GameBalance.get_number("settings_control_height")
		if not control is CheckButton:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(control)
	focus_entered.connect(_highlight)
	focus_exited.connect(_highlight)
	mouse_entered.connect(func():
		hovered = true
		_highlight()
	)
	mouse_exited.connect(func():
		hovered = false
		_highlight()
	)
	_highlight()


func _ready() -> void:
	for child: Control in find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_PASS
		child.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				grab_focus()
		)


func _highlight() -> void:
	var style := SettingsControls.row_style(hovered or has_focus())
	add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
	var direction := 0
	if event.is_action_pressed("ui_left"):
		direction = -1
	elif event.is_action_pressed("ui_right"):
		direction = 1
	if direction != 0:
		if control is SettingsSelector:
			control.change(direction)
		elif control is CheckButton:
			control.button_pressed = not control.button_pressed
		elif control is HSlider:
			control.value += direction * control.step
		accept_event()
	elif event.is_action_pressed("ui_accept") and control is CheckButton:
		control.button_pressed = not control.button_pressed
		accept_event()
	elif event.is_action_pressed("ui_accept") and control is KeyBindButton:
		control.start_capture()
		accept_event()
