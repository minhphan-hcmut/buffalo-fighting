extends SceneTree

const HOWTO = preload("res://scripts/ui/how_to_play.gd")
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
	var howto := HOWTO.new()
	root.add_child(howto)
	for frame in 4:
		await process_frame
	var rules: Control = howto.pages[0]
	check(rules.get_child_count() == 3, "Rules contains exactly three visual cards")
	check(root.get_visible_rect().encloses(howto.panel.get_global_rect()), "Rules keeps the existing panel inside 1280x720")
	for card: Control in rules.get_children():
		var diagram := card.get_node("Diagram") as Control
		var caption := card.get_node("Caption") as RichTextLabel
		check(diagram.has_method("refresh") and diagram.custom_minimum_size.y > 0.0, "each card has a drawn diagram")
		check(howto.panel.get_global_rect().encloses(card.get_global_rect()) and card.get_global_rect().encloses(diagram.get_global_rect()), "card and diagram fit the panel")
		check(caption.get_line_count() <= 3 and caption.get_content_width() <= caption.size.x, "card caption fits within three short lines")
		check(caption.get_theme_font_size("normal_font_size") >= GameBalance.get_int("ui_howto_body_font_size"), "card caption retains the body font size")
		for label: Label in diagram.get_children():
			check(label.get_theme_font_size("font_size") >= GameBalance.get_int("ui_howto_body_font_size") and diagram.get_global_rect().encloses(label.get_global_rect()), "diagram label is readable and fits: " + label.name)
	var values := {"match_duration_s": 75.0, "stamina_max": 120.0, "flank_damage_multiplier": 1.6, "back_damage_multiplier": 1.7, "pinned_spirit_multiplier": 1.8}
	var originals := {}
	for key in values:
		originals[key] = GameBalance.get_number(key)
		GameBalance.values[key] = values[key]
	for card in rules.get_children():
		card.get_node("Diagram").refresh()
	check(rules.get_node("RuleCard0/Diagram/Clock").text == "75 giây", "clock label reads changed GameBalance duration")
	check(rules.get_node("RuleCard1/Diagram/Stamina").text == "SỨC · 120", "stamina label reads changed GameBalance maximum")
	check(rules.get_node("RuleCard2/Diagram/Flank").text == "Sườn ×1.6", "flank multiplier label reads changed GameBalance value")
	check(rules.get_node("RuleCard2/Diagram/BackMultiplier").text == "Lưng ×1.7", "back multiplier label reads changed GameBalance value")
	check(rules.get_node("RuleCard2/Diagram/Fence").text == "Sát rào ×1.8", "fence multiplier label reads changed GameBalance value")
	for key in originals:
		GameBalance.values[key] = originals[key]
	howto.tabs[0].grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	root.push_input(key)
	check(howto.selected_tab == 1 and howto.tabs[1].has_focus() and howto.demo != null, "Right still reaches the unchanged lazy move demos")
	howto.tabs[2].grab_focus()
	howto.tabs[2].pressed.emit()
	check(howto.selected_tab == 2 and not howto.demo.is_physics_processing(), "Controls tab still suspends the demos")
	howto.tabs[0].grab_focus()
	howto.tabs[0].pressed.emit()
	check(howto.selected_tab == 0 and rules.visible, "returning to Rules restores the three cards")
	var closed := [false]
	howto.closed.connect(func(): closed[0] = true)
	key.keycode = KEY_ESCAPE
	root.push_input(key)
	check(closed[0], "Esc still closes How to Play")
	await process_frame
	print("HOWTO RULES TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
