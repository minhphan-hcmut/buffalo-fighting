extends SceneTree
## Loading screen (2026-11-22): the arena still under the scene fade and the shader warm-up cover.

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	var card_script := load("res://scripts/ui/loading_card.gd") as GDScript
	check(card_script != null, "loading card script exists")
	if card_script != null:
		var card: Control = card_script.build()
		root.add_child(card)
		await process_frame
		var image := card.find_child("Arena", true, false) as TextureRect
		check(image != null and image.texture != null and image.get_global_rect().encloses(root.get_visible_rect()), "arena image covers the screen")
		var caption := card.find_child("Caption", true, false) as Label
		check(caption != null and caption.text == "ĐANG VÀO SÂN" and root.get_visible_rect().encloses(caption.get_global_rect()), "caption is on screen")
		check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "card never eats input")
		card.free()

	SessionState.return_to_menu()
	SessionState.begin_solo()
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	var cover: Node = arena.vfx.warm_cover if arena.vfx != null else null
	check(cover != null and is_instance_valid(cover) and cover.find_child("LoadingCard", true, false) != null, "shader warm-up hides behind the same arena card")
	for frame in GameBalance.get_int("vfx_warm_up_settle_frames") + GameBalance.get_int("vfx_warm_up_frames") + 4:
		await process_frame
	check(not is_instance_valid(cover) or cover.is_queued_for_deletion(), "the card leaves once the warm-up is done")
	arena.free()
	SessionState.return_to_menu()
	await process_frame
	print("Loading card: %d failures" % failures)
	quit(0 if failures == 0 else 1)
