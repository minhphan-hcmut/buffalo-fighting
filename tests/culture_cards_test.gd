extends SceneTree

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
	var data := DataFile.load_json("res://data/culture_cards.json")
	var cards: Array = data.get("cards", [])
	check(cards.size() == 5, "culture data contains exactly five cards")
	var seen: Array[StringName] = []
	for card: Dictionary in cards:
		var words := String(card.body).split(" ", false).size()
		check(words >= 20 and words <= 40, "%s is a short fun fact (20–40 words, got %d)" % [card.id, words])
		check(not card.has("source"), "%s shows no source citation" % card.id)
		check(CultureCards.next_card(seen, false) == card, "unseen cards follow file order: %s" % card.id)
		seen.append(StringName(card.id))
	check(CultureCards.next_card(seen, false).is_empty(), "all seen returns no card")
	check(CultureCards.next_card(seen, true).is_empty(), "final win also returns no card when exhausted")
	seen = [StringName(cards[1].id)]
	check(CultureCards.next_card(seen, false) == cards[0], "skips seen cards without skipping earlier unseen cards")
	check(seen.size() == 1, "selection does not mutate the caller's seen list")
	seen.clear()
	check(CultureCards.next_card(seen, true).id == data.final_card, "final win prioritizes unseen final card")
	seen.append(StringName(data.final_card))
	check(CultureCards.next_card(seen, true) == cards[0], "seen final card falls back to next unseen card")
	SessionState.culture_cards_seen.assign(seen)
	SessionState.return_to_menu()
	check(SessionState.culture_cards_seen.is_empty(), "returning to menu clears seen cards")

	root.size = Vector2i(1280, 720)
	var overlay := Control.new()
	overlay.name = "SoloSessionOverlay"
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	overlay.show()
	SessionState.last_match_level = &"L01"
	SessionState.last_winner = 1
	SessionState.last_reason = &"TIME"
	overlay._show_result("L01:1:TIME")
	overlay._show_result("L01:1:TIME")
	await process_frame
	await process_frame
	var panel := overlay.find_child("CultureCard", true, false) as PanelContainer
	check(SessionState.culture_cards_seen == [StringName(cards[0].id)], "same result shown twice consumes only one card")
	check(panel != null, "Solo result contains CultureCard panel")
	if panel != null:
		check(panel.get_child(0).get_child(1).text == cards[0].title, "panel shows first card title")
		check(panel.get_child(0).get_child(0).text == "%s · 1/5" % data.label, "panel shows session card count")
		check(panel.get_index() < overlay.result_actions.get_index(), "card precedes existing result actions")
		_check_layout(overlay, panel)
	await create_timer(GameBalance.get_number("ui_culture_card_fade_s") + 0.05).timeout
	check(panel != null and is_equal_approx(panel.modulate.a, 1.0), "card fades fully into view")

	# Scene changes reset the guard even if a replay ends with identical result text.
	scene_changed.emit()
	overlay._show_result("L01:1:TIME")
	check(SessionState.culture_cards_seen.size() == 2, "replay with identical result consumes the next card")
	await process_frame
	await process_frame
	_check_layout(overlay, overlay.find_child("CultureCard", true, false))
	for index in range(2, cards.size()):
		SessionState.last_winner = 2 if index == 2 else 1
		SessionState.last_reason = &"FLEE"
		overlay._show_result("loss:%d" % index)
		await process_frame
		await process_frame
		panel = overlay.find_child("CultureCard", true, false) as PanelContainer
		check(panel.get_child(0).get_child(1).text == cards[index].title, "wins and losses unlock %s" % cards[index].id)
		_check_layout(overlay, panel)
	overlay._show_result("exhausted")
	check(overlay.find_child("CultureCard", true, false) == null, "exhausted session has no card panel")
	check(overlay.result_panel.offset_left == 64.0 and overlay.result_panel.offset_top == -230.0, "no card restores original panel layout")

	SessionState.return_to_menu()
	SessionState.mode = &"LAN"
	overlay._show_result("lan")
	check(SessionState.culture_cards_seen.is_empty() and overlay.find_child("CultureCard", true, false) == null, "LAN neither consumes nor shows culture cards")
	SessionState.mode = &"SOLO"
	SessionState.last_match_level = &"L03"
	SessionState.last_winner = 1
	overlay._show_result("L03:1:TIME")
	panel = overlay.find_child("CultureCard", true, false) as PanelContainer
	var ceremony := overlay.find_child("Ceremony", true, false) as CeremonyView
	check(SessionState.culture_cards_seen == [StringName(data.final_card)], "final overlay selects heritage card")
	check(ceremony != null and not overlay.result_panel.visible and panel.modulate.a == 0.0, "final card waits behind closing ceremony")
	if ceremony != null:
		ceremony.finish()
	await create_timer(GameBalance.get_number("ui_culture_card_fade_s") + 0.05).timeout
	check(overlay.result_panel.visible and is_equal_approx(panel.modulate.a, 1.0), "final card fades in after closing ceremony")
	_check_layout(overlay, panel)
	overlay.free()
	SessionState.return_to_menu()
	await process_frame
	print("CULTURE CARDS TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _check_layout(overlay: Control, panel: PanelContainer) -> void:
	check(root.get_visible_rect().encloses(overlay.result_panel.get_global_rect()), "result panel fits 1280x720: %s" % overlay.result_panel.get_global_rect())
	check(panel.get_global_rect().end.x <= 640.0, "culture card stays in left half")
	check(panel.get_global_rect().end.y <= overlay.result_actions.get_global_rect().position.y, "card does not overlap result actions")
	for label: Label in panel.get_child(0).get_children():
		check(panel.get_global_rect().encloses(label.get_global_rect()), "card text stays inside panel")
