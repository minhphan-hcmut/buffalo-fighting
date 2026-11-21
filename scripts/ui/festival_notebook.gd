class_name FestivalNotebook
extends HBoxContainer
## Read-only collection; session card selection and season progress remain independent.

var entries: Array[Button] = []
var heading: Label
var body: RichTextLabel
var reader: ScrollContainer
var cards: Array = []


func _ready() -> void:
	name = "Notebook"
	add_theme_constant_override("separation", GameBalance.get_int("ui_howto_column_gap"))
	cards = DataFile.load_json("res://data/culture_cards.json").get("cards", [])
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = GameBalance.get_number("ui_notebook_list_width")
	list.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_gap"))
	add_child(list)
	for card: Dictionary in cards:
		var entry := Button.new()
		entry.theme_type_variation = &"QuietButton"
		entry.name = card.id
		entry.custom_minimum_size.y = GameBalance.get_number("ui_notebook_row_height")
		entry.add_theme_font_size_override("font_size", GameBalance.get_int("ui_culture_card_title_font_size"))
		entry.pressed.connect(show_card.bind(entries.size()))
		entry.focus_entered.connect(show_card.bind(entries.size()))
		entries.append(entry)
		list.add_child(entry)
	reader = ScrollContainer.new()
	reader.name = "Reader"
	reader.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(reader)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_gap"))
	reader.add_child(text)
	heading = ControlsDiagram.label("", "title", ControlsDiagram.GOLD)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(heading)
	body = RichTextLabel.new()
	body.name = "CardText"
	body.fit_content = true
	body.scroll_active = false
	body.focus_mode = Control.FOCUS_ALL
	body.gui_input.connect(_reader_input)
	body.add_theme_font_size_override("normal_font_size", GameBalance.get_int("ui_notebook_body_font_size"))
	body.add_theme_color_override("default_color", ControlsDiagram.PAPER)
	text.add_child(body)
	refresh()


func refresh() -> void:
	for index in entries.size():
		var card: Dictionary = cards[index]
		entries[index].text = card.title if CultureCards.has_seen(StringName(card.id)) else Language.t("%d · Chưa mở") % (index + 1)
	show_card(0)


func show_card(index: int) -> void:
	var card: Dictionary = cards[index]
	var seen := CultureCards.has_seen(StringName(card.id))
	heading.text = card.title if seen else "Chưa mở"
	body.text = card.body if seen else (Language.t("Chưa mở — xem ở vòng %s") % Language.t(card.round) if card.has("round") else Language.t("Chưa mở"))
	reader.scroll_vertical = 0
	for i in entries.size():
		entries[i].toggle_mode = true
		entries[i].set_pressed_no_signal(i == index)


func _reader_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		reader.scroll_vertical += GameBalance.get_int("ui_notebook_scroll_step") * (1 if event.is_action_pressed("ui_down") else -1)
		body.accept_event()
