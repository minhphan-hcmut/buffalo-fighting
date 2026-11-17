extends Node
## Owns the drill panel, counters and popup; never writes simulation state.

var controller
var write_label: Callable
var training_panel: PanelContainer
var training_counter: Label
var training_popup: Label
var training_counts: Dictionary = {}
var training_popup_time := 0.0
var training_released := false
var training_counter_dirty := false


func setup(match_controller, root: Control, label_update: Callable) -> void:
	controller = match_controller
	write_label = label_update
	if controller.training.is_empty():
		return
	for key: String in controller.training.counters:
		training_counts[key] = 0
	training_panel = PanelContainer.new()
	training_panel.name = "TrainingPanel"
	var width := GameBalance.get_number("training_panel_width")
	training_panel.position = Vector2((get_viewport().get_visible_rect().size.x - width) * 0.5, GameBalance.get_number("training_panel_top"))
	training_panel.custom_minimum_size.x = width
	root.add_child(training_panel)
	var rows := VBoxContainer.new()
	training_panel.add_child(rows)
	var title := Label.new()
	title.text = controller.training.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameBalance.get_int("training_title_font_size"))
	title.add_theme_color_override("font_color", Color("#E8BC65"))
	rows.add_child(title)
	training_counter = Label.new()
	training_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	training_counter.add_theme_font_size_override("font_size", GameBalance.get_int("training_counter_font_size"))
	rows.add_child(training_counter)
	training_popup = Label.new()
	training_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	training_popup.add_theme_font_size_override("font_size", GameBalance.get_int("training_popup_font_size"))
	training_popup.add_theme_color_override("font_color", Color("#E8BC65"))
	training_popup.visible = false
	rows.add_child(training_popup)
	training_counter.text = String(controller.training.counter_text).format(training_counts)
	controller.combat_event.connect(on_combat_event)


func _exit_tree() -> void:
	if is_instance_valid(controller) and controller.combat_event.is_connected(on_combat_event):
		controller.combat_event.disconnect(on_combat_event)
	write_label = Callable()
	# The panel stays directly under the HUD root for layout/text-scale compatibility,
	# but belongs to this presenter even when it is removed independently of the HUD.
	if is_instance_valid(training_panel):
		training_panel.free()
	training_panel = null
	training_counter = null
	training_popup = null
	controller = null


func count(key: String) -> void:
	if training_counts.has(key):
		training_counts[key] += 1
		training_counter_dirty = true


func success(text: String) -> void:
	write_label.call(training_popup, text)
	training_popup_time = GameBalance.get_number("training_popup_s")


func on_combat_event(event: StringName, source: int, target: int, _value: float) -> void:
	if source == 2 and String(event) == controller.training.get("attack_event", ""):
		count("attacks")
	if source == 1:
		if event in [&"HORN_HIT", &"DASH_HIT"]:
			count("hits")
		elif event in [&"FLANK_HIT", &"BACK_HIT"]:
			count("flanks")
		elif event == &"PARRY_SUCCESS":
			count("parried")
			success("GẠT ĐƯỢC!")
		elif event == &"COUNTER_HIT":
			count("counters")
			success("PHẢN ĐÒN!")
		elif event == &"RELEASE_START":
			training_released = true
	if event == &"CLASH_START":
		count("locks")
		training_released = false
	elif event == &"CLASH_HOOK" and source == 2:
		count("hooks")
	elif event == &"CLASH_LOSS" and target == 2:
		count("wins")
		if training_released:
			count("releases")
			success("NHẢ ĐÚNG LÚC!")
	elif event in [&"CLASH_WHIFF", &"CLASH_RELEASE", &"CLASH_BREAK", &"CLASH_TIME"]:
		training_released = false
	elif event == &"TRAINING_REFILL" and training_popup_time <= 0.0:
		success("Hồi khí thế")
	if training_counter_dirty:
		write_label.call(training_counter, String(controller.training.counter_text).format(training_counts))
		training_counter_dirty = false


func update(delta: float) -> void:
	if controller.training.is_empty():
		return
	training_popup_time = maxf(0.0, training_popup_time - (0.0 if controller.paused else delta))
	if training_popup_time <= 0.0:
		write_label.call(training_popup, "")
	# The popup line takes space only while it shows, keeping the panel two lines tall.
	if training_popup.visible != (training_popup.text != ""):
		training_popup.visible = training_popup.text != ""
		training_panel.reset_size()
