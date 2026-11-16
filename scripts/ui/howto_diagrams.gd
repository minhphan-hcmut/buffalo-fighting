class_name HowtoDiagrams
extends Control
## Small, read-only rule illustrations; numeric labels always read the combat data.

enum Kind { WIN, STAMINA, TARGET }
const TITLES := ["THẮNG THẾ NÀO", "GIỮ SỨC", "ĐÁNH CHỖ NÀO"]
const CAPTIONS := [
	"Hết giờ: khí thế cao hơn thắng\nBằng nhau: bốc thăm · Khí thế không hồi",
	"Đòn và ghìm tốn sức\nNghỉ thì hồi · Hết sức: không ghìm",
	"Dồn sát rào: mạnh hơn\nGạt sừng đúng lúc → phản đòn"
]
var kind := Kind.WIN


## Builds one diagram card without adding a focus stop or changing the move demos.
static func create_card(index: int) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.name = "RuleCard%d" % index
	card.custom_minimum_size.x = GameBalance.get_number("ui_howto_rules_card_width")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_gap"))
	card.add_child(ControlsDiagram.label(TITLES[index], "heading", ControlsDiagram.GOLD))
	var diagram := HowtoDiagrams.new()
	diagram.name = "Diagram"
	diagram.kind = index
	diagram.custom_minimum_size.y = GameBalance.get_number("ui_howto_rules_diagram_height")
	card.add_child(diagram)
	var caption := RichTextLabel.new()
	caption.name = "Caption"
	caption.bbcode_enabled = true
	caption.fit_content = true
	caption.scroll_active = false
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("normal_font_size", GameBalance.get_int("ui_howto_body_font_size"))
	caption.add_theme_color_override("default_color", ControlsDiagram.PAPER)
	var text: String = CAPTIONS[index]
	for word in ["khí thế", "Khí thế", "sức", "sát rào", "Gạt sừng", "bốc thăm"]:
		text = text.replace(word, "[b][color=#E8BC65]%s[/color][/b]" % word)
	caption.text = text
	card.add_child(caption)
	return card


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		Kind.WIN:
			_text("Spirit", "KHÍ THẾ", Rect2(0.05, 0.02, 0.5, 0.15))
			_text("Zero", "0 → lui sới", Rect2(0.62, 0.22, 0.38, 0.16))
			_text("Clock", "", Rect2(0.42, 0.65, 0.5, 0.2))
		Kind.STAMINA:
			_text("Stamina", "", Rect2(0.05, 0.02, 0.9, 0.15))
			_text("Cost", "Tốn sức", Rect2(0.58, 0.36, 0.4, 0.16))
			_text("Regen", "Nghỉ → hồi sức", Rect2(0.18, 0.65, 0.75, 0.2))
		Kind.TARGET:
			_text("Front", "Trước", Rect2(0.38, 0.0, 0.3, 0.15))
			_text("Flank", "", Rect2(0.0, 0.28, 0.42, 0.18))
			_text("BackMultiplier", "", Rect2(0.68, 0.49, 0.32, 0.18))
			_text("Fence", "", Rect2(0.13, 0.84, 0.8, 0.16))
	refresh()


## Re-reads numeric labels so diagrams cannot drift from the configured match rules.
func refresh() -> void:
	match kind:
		Kind.WIN:
			get_node("Clock").text = "%d giây" % GameBalance.get_int("match_duration_s")
		Kind.STAMINA:
			get_node("Stamina").text = "SỨC · %d" % GameBalance.get_int("stamina_max")
		Kind.TARGET:
			get_node("Flank").text = "Sườn ×%s" % GameBalance.get_number("flank_damage_multiplier")
			get_node("BackMultiplier").text = "Lưng ×%s" % GameBalance.get_number("back_damage_multiplier")
			get_node("Fence").text = "Sát rào ×%s" % GameBalance.get_number("pinned_spirit_multiplier")
	queue_redraw()


func _text(id: String, text: String, rect: Rect2) -> void:
	var label := ControlsDiagram.label(text, "body", ControlsDiagram.PAPER)
	label.name = id
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = rect.position.x
	label.anchor_top = rect.position.y
	label.anchor_right = rect.end.x
	label.anchor_bottom = rect.end.y
	add_child(label)


func _draw() -> void:
	var gold := ControlsDiagram.GOLD
	var paper := ControlsDiagram.PAPER
	var stroke := GameBalance.get_number("ui_howto_key_border_thin")
	match kind:
		Kind.WIN:
			_bar(Rect2(size * Vector2(0.06, 0.23), size * Vector2(0.38, 0.09)), 0.7, gold)
			_arrow(size * Vector2(0.48, 0.275), size * Vector2(0.59, 0.275), gold)
			var clock := size * Vector2(0.25, 0.75)
			var radius := size.y * 0.13
			draw_arc(clock, radius, 0.0, TAU, 48, paper, stroke, true)
			draw_line(clock, clock - Vector2(0.0, radius * 0.65), gold, stroke, true)
			draw_line(clock, clock + Vector2(radius * 0.5, 0.0), gold, stroke, true)
		Kind.STAMINA:
			_bar(Rect2(size * Vector2(0.06, 0.24), size * Vector2(0.88, 0.1)), 0.63, gold)
			draw_rect(Rect2(size * Vector2(0.615, 0.24), size * Vector2(0.2, 0.1)), Color("#B6453B"))
			_arrow(size * Vector2(0.18, 0.6), size * Vector2(0.72, 0.6), gold)
		Kind.TARGET:
			var body := PackedVector2Array([Vector2(0.44, 0.24), Vector2(0.61, 0.24), Vector2(0.66, 0.35), Vector2(0.64, 0.57), Vector2(0.57, 0.64), Vector2(0.46, 0.61), Vector2(0.41, 0.4)])
			for i in body.size():
				body[i] *= size
			draw_colored_polygon(body, Color("#8A7659"))
			draw_rect(Rect2(size * Vector2(0.44, 0.28), size * Vector2(0.05, 0.25)), Color("#477B9C"))
			draw_rect(Rect2(size * Vector2(0.48, 0.54), size * Vector2(0.12, 0.07)), Color("#B6453B"))
			draw_circle(size * Vector2(0.525, 0.21), size.y * 0.08, gold)
			draw_polyline(PackedVector2Array([size * Vector2(0.43, 0.1), size * Vector2(0.42, 0.2), size * Vector2(0.5, 0.23)]), paper, stroke * 2.0, true)
			draw_polyline(PackedVector2Array([size * Vector2(0.62, 0.1), size * Vector2(0.63, 0.2), size * Vector2(0.55, 0.23)]), paper, stroke * 2.0, true)
			draw_line(size * Vector2(0.35, 0.38), size * Vector2(0.44, 0.38), paper, stroke, true)
			draw_line(size * Vector2(0.57, 0.59), size * Vector2(0.67, 0.59), paper, stroke, true)
			for x in [0.14, 0.32, 0.5, 0.68, 0.86]:
				draw_line(size * Vector2(x, 0.72), size * Vector2(x, 0.84), gold, stroke * 2.0, true)
			for y in [0.76, 0.81]:
				draw_line(size * Vector2(0.1, y), size * Vector2(0.9, y), gold, stroke, true)


func _bar(rect: Rect2, amount: float, color: Color) -> void:
	draw_rect(rect, ControlsDiagram.INK)
	draw_rect(Rect2(rect.position, rect.size * Vector2(amount, 1.0)), color)
	draw_rect(rect, Color(ControlsDiagram.PAPER, 0.4), false, GameBalance.get_number("ui_howto_key_border_thin"))


func _arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var width := GameBalance.get_number("ui_howto_key_border_thin")
	var head := size.y * 0.025
	draw_line(from, to, color, width, true)
	draw_polyline(PackedVector2Array([to + Vector2(-head, -head), to, to + Vector2(-head, head)]), color, width, true)
