class_name SettingsSelector
extends HBoxContainer
## Inline choices wrap in both directions; the containing row owns keyboard focus.

signal item_selected(index: int)

var choices: Array
var selected := 0
var selectable_count := 0
var value_label: Label


func _init(values: Array = []) -> void:
	choices = values
	selectable_count = values.size()
	add_theme_constant_override("separation", 0)
	for direction in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "‹" if direction < 0 else "›"
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.custom_minimum_size = Vector2(GameBalance.get_number("settings_control_height"), GameBalance.get_number("settings_control_height"))
		SettingsControls.quiet_button(arrow)
		arrow.add_theme_font_size_override("font_size", GameBalance.get_int("settings_arrow_size"))
		arrow.add_theme_color_override("font_color", ControlsDiagram.GOLD)
		arrow.pressed.connect(change.bind(direction))
		add_child(arrow)
		if direction < 0:
			value_label = Label.new()
			value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.add_theme_color_override("font_color", ControlsDiagram.PAPER)
			value_label.add_theme_font_size_override("font_size", GameBalance.get_int("settings_label_size"))
			add_child(value_label)
	if not choices.is_empty():
		select(0)


func select(index: int) -> void:
	selected = index
	value_label.text = choices[index]


func change(direction: int) -> void:
	if selected >= selectable_count:
		selected = -1 if direction > 0 else selectable_count
	select(wrapi(selected + direction, 0, selectable_count))
	item_selected.emit(selected)
