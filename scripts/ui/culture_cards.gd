class_name CultureCards
extends RefCounted
## Selects an unseen Solo culture card without changing the session or match state.

const NOTEBOOK_PATH := "user://festival_notebook.json"
static var notebook_path := NOTEBOOK_PATH
static var notebook_seen: Array[StringName] = []
static var _notebook_loaded := false


static func load_notebook(path: String = NOTEBOOK_PATH) -> void:
	notebook_path = path
	_notebook_loaded = true
	notebook_seen.clear()
	if _test_file() or not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var saved: Variant = json.data
	var cards: Array = DataFile.load_json("res://data/culture_cards.json").get("cards", [])
	if not saved is Array or saved.size() > cards.size():
		return
	var valid: Array[StringName] = []
	for id: Variant in saved:
		if not id is String or StringName(id) in valid or not cards.any(func(card: Dictionary): return card.id == id):
			return
		valid.append(StringName(id))
	notebook_seen.assign(valid)


static func has_seen(id: StringName) -> bool:
	if not _notebook_loaded:
		load_notebook()
	return id in notebook_seen


## Called only when the result card becomes visible, including after the closing rite.
static func mark_shown(id: StringName) -> void:
	if has_seen(id):
		return
	var cards: Array = DataFile.load_json("res://data/culture_cards.json").get("cards", [])
	if not cards.any(func(card: Dictionary): return card.id == String(id)):
		return
	notebook_seen.append(id)
	if _test_file():
		return
	var file := FileAccess.open(notebook_path, FileAccess.WRITE)
	if file == null:
		push_warning("Không thể lưu sổ tay: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(notebook_seen))
	if file.get_error() != OK:
		push_warning("Không thể lưu sổ tay: %s" % error_string(file.get_error()))


static func _test_file() -> bool:
	return notebook_path == NOTEBOOK_PATH and OS.get_cmdline_args().has("--script")


static func next_card(seen: Array[StringName], is_final_win: bool) -> Dictionary:
	var data := DataFile.load_json("res://data/culture_cards.json")
	var cards: Array = data.get("cards", [])
	if is_final_win:
		for card: Dictionary in cards:
			if card.id == data.get("final_card", "") and StringName(card.id) not in seen:
				return card
	for card: Dictionary in cards:
		if StringName(card.id) not in seen:
			return card
	return {}
