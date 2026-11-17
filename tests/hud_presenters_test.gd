extends SceneTree
## Catches split state ownership, lost/duplicate event wiring and stale callbacks on HUD replacement.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func fixture(drill: StringName = &"") -> MatchController:
	SessionState.return_to_menu()
	if drill != &"":
		SessionState.begin_training(drill)
	else:
		SessionState.begin_solo()
	SessionState.auto_pause_enabled = false
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.hud.set_process(false)
	arena.start_playing()
	return arena


func settle() -> void:
	for frame in 8:
		await process_frame


func tutorial_path(arena: MatchController) -> void:
	var hud = arena.hud
	check(hud.get_node_or_null("TutorialPresenter") != null, "tutorial event/state owner is a scene-owned presenter")
	check(hud.get_child(0) is Control, "HUD root Control remains first child")
	arena.player.position = Vector3.ZERO
	arena.player.facing = Vector3.FORWARD
	arena.opponent.position = Vector3(0, 0, -4)
	hud._process(0.0)
	check(hud.tutorial_current == 1 and hud.tutorial_queue == [3], "real PLAYING path queues distance tutorial after movement hint")
	arena.combat_event.emit(&"HORN_HIT", 2, 1, 18.0)
	arena.combat_event.emit(&"CLASH_START", 1, 2, 0.0)
	check(hud.tutorial_front_hit and hud.tutorial_queue == [3, 4, 5], "controller front-hit and clash signals populate ordered queue")
	var time: float = hud.tutorial_time
	var controls_time: float = hud.controls_hint_time
	arena.request_pause_from_menu()
	hud._process(2.0)
	check(hud.tutorial_time == time and hud.controls_hint_time == controls_time and hud.tutorial_current == 1, "pause render path freezes tutorial and control clocks")
	arena.resume_from_menu()
	for id in [3, 4, 5, 6]:
		hud._process(GameBalance.get_number("tutorial_hint_s"))
		check(hud.tutorial_current == id and hud.tutorial_label.visible, "resume renders queued tutorial %d" % id)
	check(hud.tutorial_label.get_parsed_text().contains("phản đòn"), "front hit renders counter tutorial only after guard tutorial")
	# Compatibility writes must mutate the presenter's sole state, not a HUD copy.
	var presenter = hud.get_node_or_null("TutorialPresenter")
	if presenter != null:
		var pending: Array[int] = [2]
		hud.tutorial_queue = pending
		check(presenter.tutorial_queue == [2], "compatibility queue setter reaches presenter state")
		presenter.tutorial_queue.clear()
		check(hud.tutorial_queue.is_empty(), "compatibility queue getter exposes the same mutable state")


func training_path(arena: MatchController) -> void:
	var hud = arena.hud
	check(hud.get_node_or_null("TrainingPresenter") != null, "training event/state owner is a scene-owned presenter")
	check(hud.training_panel.name == "TrainingPanel" and hud.training_panel.get_parent() == hud.get_child(0), "training keeps root panel identity")
	hud._process(0.0)
	var writes: int = hud.label_writes
	arena.combat_event.emit(&"HORN_START", 2, 1, 0.0)
	arena.combat_event.emit(&"DASH_START", 1, 2, 0.0)
	arena.combat_event.emit(&"PARRY_SUCCESS", 2, 1, 0.0)
	check(hud.training_counts.attacks == 0 and hud.training_counts.parried == 0 and hud.label_writes == writes, "wrong drill attack and remote parry do not change counters or dirty writes")
	arena.combat_event.emit(&"DASH_START", 2, 1, 0.0)
	check(hud.training_counts.attacks == 1 and hud.label_writes == writes + 1, "matching opponent drill event writes counter exactly once")
	writes = hud.label_writes
	arena.combat_event.emit(&"PARRY_SUCCESS", 1, 2, 0.0)
	check(hud.training_counts.parried == 1 and hud.training_popup.text == "GẠT ĐƯỢC!" and hud.label_writes == writes + 2, "local success writes popup and counter through HUD dirty accounting")
	arena.request_pause_from_menu()
	var popup_time: float = hud.training_popup_time
	hud._process(2.0)
	check(hud.training_popup_time == popup_time and hud.training_popup.visible, "paused render retains training popup time")
	arena.resume_from_menu()
	GraphicsQuality.set_preset(GraphicsQuality.LOW)
	hud.refresh_elapsed = 0.0
	hud._process(0.01)
	check(hud.training_popup_time == popup_time, "low preset defers popup decay with HUD refresh")
	hud._process(0.03)
	check(is_equal_approx(hud.training_popup_time, popup_time - 0.04), "low preset passes accumulated delta to presenter")
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	hud._process(GameBalance.get_number("training_popup_s"))
	check(hud.training_popup.text.is_empty() and not hud.training_popup.visible, "render clears expired popup and collapses its line")
	hud.controls_hint_time = 100.0
	hud.fight_banner_time = 100.0
	hud._process(0.0)
	writes = hud.label_writes
	var ranges: int = hud.range_writes
	for frame in 30:
		hud._process(0.0)
	check(hud.label_writes == writes and hud.range_writes == ranges, "presenter stable render performs no extra text/range writes")


func replace_hud(arena: MatchController) -> void:
	var old = arena.hud
	var tutorial = weakref(old.get_node_or_null("TutorialPresenter")) if old.has_node("TutorialPresenter") else null
	var training = weakref(old.get_node_or_null("TrainingPresenter")) if old.has_node("TrainingPresenter") else null
	var subscriptions := arena.combat_event.get_connections().size()
	old.free()
	# Emit while the controller lives but its old view does not; no callback may access freed UI.
	arena.combat_event.emit(&"PARRY_SUCCESS", 1, 2, 0.0)
	var hud := CanvasLayer.new()
	hud.set_script(load("res://scripts/ui/hud.gd"))
	hud.controller = arena
	arena.hud = hud
	arena.add_child(hud)
	hud.set_process(false)
	check(arena.combat_event.get_connections().size() == subscriptions, "HUD recreation replaces subscriptions without duplicates")
	check(tutorial != null and tutorial.get_ref() == null and training != null and training.get_ref() == null, "free releases both presenter owners and their callbacks")
	arena.combat_event.emit(&"DASH_START", 2, 1, 0.0)
	check(hud.training_counts.attacks == 1, "recreated view handles each controller event once with fresh state")
	hud._process(0.0)
	check(hud.training_counter.text.contains("1"), "recreated training view renders the new counter")


func run() -> void:
	root.size = Vector2i(1280, 720)
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	var arena := fixture()
	tutorial_path(arena)
	await settle()
	arena.free()
	arena = fixture(&"dash")
	training_path(arena)
	replace_hud(arena)
	await settle()
	arena.free()
	arena = fixture(&"dash")
	check(arena.hud.training_counts.attacks == 0 and arena.hud.training_counts.parried == 0, "new scene has fresh training counters after prior scene free")
	arena.combat_event.emit(&"DASH_START", 2, 1, 0.0)
	check(arena.hud.training_counts.attacks == 1, "new scene has one active training subscription")
	await settle()
	arena.free()
	SessionState.return_to_menu()
	await process_frame
	print("HUD PRESENTERS: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)
