class_name ControlsDiagram
extends VBoxContainer
## Keyboard and mouse diagram, sharing keycap styling with the move demos.

const GOLD := Color("#E8BC65")
const PAPER := Color("#F2E6CF")
const INK := Color("#241D18")


func _ready() -> void:
	add_theme_constant_override("separation", GameBalance.get_int("ui_howto_gap"))
	var devices := HBoxContainer.new()
	devices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	devices.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_column_gap"))
	add_child(devices)
	var keyboard := VBoxContainer.new()
	keyboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keyboard.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	devices.add_child(keyboard)
	keyboard.add_child(label("BÀN PHÍM", "heading", GOLD))
	# Esc and F12 share a row so the page fits the 720p panel above "QUAY LẠI".
	var system := _key_row(keyboard, ["Esc"], "Tạm dừng")
	var gap := Control.new()
	gap.custom_minimum_size.x = GameBalance.get_number("ui_howto_gap") * 2.0
	system.add_child(gap)
	system.add_child(keycap("F12"))
	system.add_child(label("Chụp màn hình", "body", PAPER))
	_key_row(keyboard, ["Q", "W", "E", "R", "T"], Language.t("%s · Đi theo hướng camera") % spaced_moves())
	_key_row(keyboard, ["A", "S", "D", "F", "G"], Language.t("%s · Gạt sừng đúng lúc") % KeyBindings.label("parry"))
	_key_row(keyboard, [KeyBindings.label("dash")], "Hổ lao")
	keyboard.add_child(label("Phím vàng là phím dùng trong trận.", "body", PAPER))
	var mouse := VBoxContainer.new()
	mouse.custom_minimum_size.x = GameBalance.get_number("ui_howto_mouse_width")
	mouse.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	devices.add_child(mouse)
	mouse.add_child(label("CHUỘT", "heading", GOLD))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	mouse.add_child(buttons)
	for item in [[Language.t("Chuột trái"), _mouse_action(MOUSE_BUTTON_LEFT)], [Language.t("Chuột phải"), _mouse_action(MOUSE_BUTTON_RIGHT)]]:
		var cap := keycap(item[0] + "\n" + item[1], item[1] != "—")
		cap.name = "MouseLeft" if item[0] == "Chuột trái" else "MouseRight"
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cap.custom_minimum_size.y = GameBalance.get_number("ui_howto_mouse_button_height")
		var top := cap.get_theme_stylebox("panel") as StyleBoxFlat
		if item[0] == "Chuột trái":
			top.corner_radius_top_left = GameBalance.get_int("ui_howto_mouse_corner_radius")
		else:
			top.corner_radius_top_right = GameBalance.get_int("ui_howto_mouse_corner_radius")
		buttons.add_child(cap)
	var body := keycap("Di chuột:\nnhìn quanh", false)
	body.custom_minimum_size.y = GameBalance.get_number("ui_howto_mouse_body_height")
	var bottom := body.get_theme_stylebox("panel") as StyleBoxFlat
	bottom.corner_radius_bottom_left = GameBalance.get_int("ui_howto_mouse_corner_radius")
	bottom.corner_radius_bottom_right = GameBalance.get_int("ui_howto_mouse_corner_radius")
	mouse.add_child(body)
	var clash := PanelContainer.new()
	clash.name = "ClashControls"
	add_child(clash)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	clash.add_child(content)
	content.add_child(label("KHÓA SỪNG", "heading", GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_gap"))
	content.add_child(row)
	for item in [[spaced_moves(), "Đẩy về đối thủ"], [KeyBindings.label("horn"), "Móc"], [KeyBindings.label("guard"), "Nhả"]]:
		row.add_child(keycap(item[0]))
		row.add_child(label(item[1], "body", PAPER))
	content.add_child(label("Nhả lúc đối thủ móc khiến họ mất khí thế; nhả sai lúc bạn mất khí thế.", "body", PAPER))


func _key_row(parent: Container, keys: Array, action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	parent.add_child(row)
	var used := ["Esc", "F12"]
	for entry in KeyBindings.ACTIONS:
		used.append(KeyBindings.label(entry[0]))
	for key: String in keys:
		var cap := keycap(key, key in used)
		if key.length() > 3:
			cap.custom_minimum_size.x = GameBalance.get_number("ui_howto_space_width")
		row.add_child(cap)
	row.add_child(label(action, "body", PAPER))
	return row


## "W A S D" for single-letter movement keys, else names joined by "/".
static func spaced_moves() -> String:
	var moves := KeyBindings.move_label()
	return moves if moves.contains("/") else " ".join(moves.split(""))


## What a mouse button does in a match, "—" when nothing is bound to it.
static func _mouse_action(button: MouseButton) -> String:
	var names := {"horn": "Húc", "guard": "Ghìm (giữ)", "dash": "Hổ lao", "parry": "Gạt sừng"}
	for entry in KeyBindings.ACTIONS:
		if KeyBindings.bindings[entry[0]] == "m%d" % button:
			return Language.t(names.get(entry[0], entry[1]))
	return "—"


## A shared festival keycap; unused context keys retain the muted fill.
static func keycap(text: String, used := true) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.custom_minimum_size = Vector2.ONE * GameBalance.get_number("ui_howto_key_size")
	var style := StyleBoxFlat.new()
	style.bg_color = GOLD if used else INK
	style.border_color = Color("#E8BC6550")
	style.set_border_width_all(GameBalance.get_int("ui_howto_key_border_thin"))
	style.set_corner_radius_all(GameBalance.get_int("ui_howto_key_corner_radius"))
	style.content_margin_left = GameBalance.get_number("ui_howto_key_horizontal_padding")
	style.content_margin_right = style.content_margin_left
	style.content_margin_top = GameBalance.get_number("ui_howto_key_padding")
	style.content_margin_bottom = style.content_margin_top
	cap.add_theme_stylebox_override("panel", style)
	var text_label := label(text, "body", INK if used else Color("#BAAA90"))
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(text_label)
	return cap


## A label using the instruction panel's typography tokens.
static func label(text: String, kind := "body", color := PAPER) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", GameBalance.get_int("ui_howto_%s_font_size" % kind))
	result.add_theme_color_override("font_color", color)
	return result
