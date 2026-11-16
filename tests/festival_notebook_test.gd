extends SceneTree

const SAVE := "user://festival_notebook_test.json"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	MatchInput.configure_ui()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	CultureCards.load_notebook(SAVE)
	var cards: Array = DataFile.load_json("res://data/culture_cards.json").cards
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_how_to_play()
	var howto := menu.get_node("HowToPlay") as HowToPlay
	howto.tabs[3].grab_focus()
	howto.tabs[3].pressed.emit()
	await process_frame
	await process_frame
	var notebook := howto.notebook
	check(notebook != null and notebook.entries.size() == cards.size(), "notebook lists every data card")
	for index in cards.size():
		check(notebook.entries[index].name == cards[index].id and notebook.entries[index].text.contains("Chưa mở"), "unseen entry is locked: " + cards[index].id)
		notebook.entries[index].grab_focus()
		check(notebook.heading.text == "Chưa mở" and notebook.body.text == "Chưa mở", "unseen text is not disclosed")
	check(howto.demo == null, "opening Notebook never constructs the move demo")
	check(root.get_visible_rect().encloses(howto.panel.get_global_rect()), "notebook fits 1280x720")

	SessionState.return_to_menu()
	SessionState.begin_free_play(&"L03")
	var progress := SessionState.unlocked_level
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	overlay.show()
	SessionState.last_winner = 1
	SessionState.last_reason = &"TIME"
	overlay._show_result("free-result")
	check(CultureCards.has_seen(StringName(cards[0].id)), "a visible free-play result unlocks its card")
	check(SessionState.unlocked_level == progress and SessionState.free_play, "notebook does not change season progress or mode")
	CultureCards.load_notebook(SAVE)
	check(CultureCards.notebook_seen == [StringName(cards[0].id)], "result unlock survives a disk reload")
	SessionState.return_to_menu()
	check(CultureCards.has_seen(StringName(cards[0].id)), "return to menu preserves the collection")
	notebook.refresh()
	notebook.entries[0].grab_focus()
	check(notebook.heading.text == cards[0].title and notebook.body.text == cards[0].body, "unlocked card shows its complete title and text")
	check(notebook.entries[1].text.contains("Chưa mở"), "unlocking one leaves other entries locked")

	SessionState.begin_solo()
	SessionState.last_match_level = &"L05"
	SessionState.last_winner = 1
	overlay._show_result("final-result")
	var ceremony := overlay.find_child("Ceremony", true, false) as CeremonyView
	var final_id := StringName(DataFile.load_json("res://data/culture_cards.json").final_card)
	check(ceremony != null and not CultureCards.has_seen(final_id), "hidden final card does not unlock behind the closing rite")
	ceremony.finish()
	await process_frame
	check(CultureCards.has_seen(final_id), "season card unlocks when closing rite reveals the result")
	overlay.free()

	# A future longer translation must remain reachable by keyboard and gamepad.
	notebook.cards = notebook.cards.duplicate(true)
	notebook.cards[0].body = String(cards[0].body).repeat(40)
	notebook.show_card(0)
	await process_frame
	await process_frame
	notebook.body.grab_focus()
	await process_frame
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	root.push_input(down)
	check(notebook.reader.scroll_vertical > 0, "keyboard scrolls long Vietnamese text")
	var before := notebook.reader.scroll_vertical
	var pad_down := InputEventJoypadButton.new()
	pad_down.button_index = JOY_BUTTON_DPAD_DOWN
	pad_down.pressed = true
	root.push_input(pad_down)
	check(notebook.reader.scroll_vertical > before, "gamepad scrolls long Vietnamese text")
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(howto.panel.get_global_rect()), "notebook fits 1920x1080")
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	root.push_input(cancel)
	await process_frame
	check(menu.get_node_or_null("HowToPlay") == null and menu.menu_layout.get_node("HowToPlayButton").has_focus(), "gamepad B closes Notebook and restores menu focus")
	menu._show_how_to_play()
	(menu.get_node("HowToPlay") as HowToPlay).tabs[3].grab_focus()
	(menu.get_node("HowToPlay") as HowToPlay).tabs[3].pressed.emit()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(menu.get_node_or_null("HowToPlay") == null and menu.menu_layout.get_node("HowToPlayButton").has_focus(), "Esc closes Notebook and restores menu focus")
	menu.free()

	for corrupt: String in ["broken json", "{}", "[123]", '["unknown"]', '["ong_trau", "ong_trau"]', '["ong_trau", null]']:
		var file := FileAccess.open(SAVE, FileAccess.WRITE)
		file.store_string(corrupt)
		file.close()
		CultureCards.load_notebook(SAVE)
		check(CultureCards.notebook_seen.is_empty(), "corrupt save is safely empty: " + corrupt)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	CultureCards.load_notebook(SAVE)
	check(CultureCards.notebook_seen.is_empty(), "missing save starts empty")
	CultureCards.mark_shown(&"unknown")
	check(CultureCards.notebook_seen.is_empty(), "unknown card ids cannot be recorded")
	CultureCards.load_notebook()
	SessionState.return_to_menu()
	await process_frame
	print("FESTIVAL NOTEBOOK TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
