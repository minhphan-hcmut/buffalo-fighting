extends Node
## Scene-owned, read-only tutorial state and combat-event observer.
## Untyped controller avoids a HUD -> presenter -> MatchController -> HUD type cycle.

## Hints read the current key bindings (Cài đặt → Điều khiển), so a rebind shows here too.
static func controls_pairs() -> Array:
	return [
		[KeyBindings.move_label(), "Đi"],
		[Language.t("Chuột"), "Nhìn"],
		[KeyBindings.short_label("horn"), "Húc"],
		[KeyBindings.short_label("dash"), "Hổ lao"],
		[KeyBindings.short_label("guard"), "Ghìm"],
		[KeyBindings.short_label("parry"), "Gạt sừng"],
		["Esc", "Tạm dừng"],
	]


static func controls_text() -> String:
	var items := PackedStringArray()
	for pair in controls_pairs():
		items.append("%s %s" % [pair[0], Language.t(pair[1])])
	return " · ".join(items)


static func tutorial_text(id: int) -> String:
	match id:
		1: return Language.t("%s để đi, chuột để nhìn") % KeyBindings.move_label()
		2: return Language.t("%s để húc khi sừng hướng về đối thủ") % KeyBindings.label("horn")
		3: return Language.t("%s để hổ lao") % KeyBindings.label("dash")
		4: return Language.t("Giữ %s để ghìm đòn phía trước") % KeyBindings.inline_label("guard")
		5: return Language.t("Đẩy về đối thủ · %s móc · %s nhả") % [KeyBindings.inline_label("horn"), KeyBindings.inline_label("guard")]
		6: return Language.t("Bấm %s đúng lúc để gạt sừng, rồi húc ngay để phản đòn") % KeyBindings.inline_label("parry")
	return controls_text()


var controller
var label: RichTextLabel
var write_text: Callable
var tutorial_seen: Array[int] = []
var tutorial_queue: Array[int] = []
var tutorial_current := 0
var tutorial_time := 0.0
var tutorial_front_hit := false
var controls_hint_time := 0.0


func setup(match_controller, hint_label: RichTextLabel, text_update: Callable) -> void:
	controller = match_controller
	label = hint_label
	write_text = text_update
	controller.combat_event.connect(on_combat_event)


func _exit_tree() -> void:
	if is_instance_valid(controller) and controller.combat_event.is_connected(on_combat_event):
		controller.combat_event.disconnect(on_combat_event)
	write_text = Callable()
	label = null
	controller = null


func enabled() -> bool:
	return controller.training.is_empty() and controller.mode == &"SOLO" and controller.level_id == &"L01"


func queue_hint(id: int) -> void:
	if not tutorial_seen.has(id) and not tutorial_queue.has(id):
		tutorial_queue.append(id)
		tutorial_queue.sort()


func on_combat_event(event: StringName, source: int, target: int, _value: float) -> void:
	if not enabled():
		return
	if event == &"CLASH_START":
		queue_hint(5)
	if target != controller.local_slot or event not in [&"HORN_HIT", &"DASH_HIT", &"CLASH_LOSS"]:
		return
	queue_hint(4)
	if event == &"HORN_HIT":
		var attacker = controller.player if source == 1 else controller.opponent
		var victim = controller.player if target == 1 else controller.opponent
		var toward: Vector3 = (attacker.global_position - victim.global_position).normalized()
		if victim.forward().dot(toward) >= cos(GameBalance.get_angle("flank_min_deg")):
			tutorial_front_hit = true


func _alpha(value: float) -> void:
	if label.modulate.a != value:
		label.modulate.a = value


func update(delta: float) -> bool:
	var hint_visible := true
	var alpha := 1.0
	if not controller.paused:
		controls_hint_time += delta
	HudText.set_size(label, "normal_font_size", GameBalance.get_int("ui_controls_font_size"))
	if not enabled():
		write_text.call(controls_text())
		var duration := GameBalance.get_number("ui_controls_hint_s")
		var fade := GameBalance.get_number("ui_controls_hint_fade_s")
		hint_visible = controls_hint_time < duration
		if hint_visible and controls_hint_time > duration - fade:
			alpha = (duration - controls_hint_time) / fade
		_alpha(alpha)
		return hint_visible
	queue_hint(1)
	var distance: float = controller.player.global_position.distance_to(controller.opponent.global_position)
	if distance <= GameBalance.get_number("tutorial_horn_range"):
		queue_hint(2)
	elif distance <= GameBalance.get_number("tutorial_dash_range"):
		queue_hint(3)
	if tutorial_front_hit and tutorial_seen.has(4):
		queue_hint(6)
	if not controller.paused:
		tutorial_time = maxf(0.0, tutorial_time - delta)
	if tutorial_time <= 0.0:
		tutorial_current = 0
		if not tutorial_queue.is_empty():
			tutorial_current = tutorial_queue.pop_front()
			tutorial_seen.append(tutorial_current)
			tutorial_time = GameBalance.get_number("tutorial_hint_s")
	write_text.call(tutorial_text(tutorial_current))
	var remaining := tutorial_time if tutorial_current > 0 else GameBalance.get_number("ui_controls_hint_s") - controls_hint_time
	var fade := GameBalance.get_number("tutorial_hint_fade_s") if tutorial_current > 0 else GameBalance.get_number("ui_controls_hint_fade_s")
	hint_visible = remaining > 0.0
	_alpha(clampf(remaining / fade, 0.0, 1.0))
	return hint_visible
