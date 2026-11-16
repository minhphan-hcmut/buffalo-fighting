class_name HudText
extends RefCounted
## Keep the original sizes so switching repeatedly never compounds the scale.


static func scale_factor() -> float:
	return GameBalance.get_number("hud_text_scale_large") if SessionState.hud_text_large else 1.0


static func set_size(control: Control, key: String, base: int) -> void:
	var meta_key := "hud_base_" + key
	if control.get_meta(meta_key, -1) != base:
		control.set_meta(meta_key, base)
	var size := roundi(base * scale_factor())
	if control.get_theme_font_size(key) != size:
		control.add_theme_font_size_override(key, size)


static func apply(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		var keys := ["normal_font_size", "bold_font_size"] if node is RichTextLabel else ["font_size"]
		for key: String in keys:
			set_size(node, key, node.get_meta("hud_base_" + key, node.get_theme_font_size(key)))
	for child in node.get_children():
		apply(child)
