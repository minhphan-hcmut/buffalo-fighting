class_name KeyBindButton
extends Button
## Settings control for one match action: press it, then press a key or mouse button.
## Esc cancels; Esc and F12 cannot be bound (pause and screenshot stay fixed).

signal rebound(action: String, swapped: String)

var action := ""
var capturing := false


func _init(bound_action: String = "") -> void:
	action = bound_action
	alignment = HORIZONTAL_ALIGNMENT_RIGHT
	flat = true
	add_theme_color_override("font_color", ControlsDiagram.GOLD)
	add_theme_color_override("font_hover_color", ControlsDiagram.GOLD)
	add_theme_color_override("font_focus_color", ControlsDiagram.GOLD)
	add_theme_font_size_override("font_size", GameBalance.get_int("settings_label_size"))
	pressed.connect(start_capture)
	refresh()


func refresh() -> void:
	capturing = false
	text = KeyBindings.label(action)


func start_capture() -> void:
	capturing = true
	text = "Nhấn phím…"


func _input(event: InputEvent) -> void:
	if not capturing or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		refresh()
		return
	var code := KeyBindings.code_for(event)
	if code.is_empty():
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	var swapped := KeyBindings.rebind(action, code)
	SessionState.save_settings()
	refresh()
	rebound.emit(action, swapped)
