extends SceneTree
## Tuning data is split in two files (see GameBalance): gameplay rules in
## data/balance.json, look and feel in data/presentation.json. Both must load, a key
## may live in only one, and GameBalance must read keys from both.

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
	var gameplay := DataFile.load_json(GameBalance.PATH)
	var presentation := DataFile.load_json(GameBalance.PRESENTATION_PATH)
	check(not gameplay.is_empty(), "balance.json loads")
	check(not presentation.is_empty(), "presentation.json loads")
	var shared: Array = []
	for key in presentation:
		if gameplay.has(key):
			shared.append(key)
	check(shared.is_empty(), "no key is in both files %s" % [shared])
	for key in ["vfx_", "ui_", "tutorial_", "camera_", "announcer_", "combat_label_"]:
		var misplaced := gameplay.keys().filter(func(k: String) -> bool: return k.begins_with(key))
		check(misplaced.is_empty(), "presentation prefix '%s' stays out of balance.json %s" % [key, misplaced])
	check(is_equal_approx(GameBalance.get_number("horn_damage"), float(gameplay["horn_damage"])), "GameBalance reads gameplay keys")
	check(is_equal_approx(GameBalance.get_number("vfx_dust_s"), float(presentation["vfx_dust_s"])), "GameBalance reads presentation keys")
	print("DATA FILES TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
