class_name MatchStats
extends RefCounted
## HORN_HIT/DASH_HIT are the primary events; counter/side events annotate the same hit.

var local_slot: int
var counts := {"hits": 0, "sides": 0, "parries": 0, "counters": 0, "dashes": 0, "locks": 0, "wins": 0, "received": 0}


func _init(slot: int = 1) -> void:
	local_slot = slot


func on_combat_event(event: StringName, source: int, target: int, _value: float) -> void:
	if event in [&"HORN_HIT", &"DASH_HIT"]:
		if source == local_slot:
			counts.hits += 1
			if event == &"DASH_HIT":
				counts.dashes += 1
		elif target == local_slot:
			counts.received += 1
	if source == local_slot:
		if event in [&"FLANK_HIT", &"BACK_HIT"]:
			counts.sides += 1
		elif event == &"PARRY_SUCCESS":
			counts.parries += 1
		elif event == &"COUNTER_HIT":
			counts.counters += 1
	if event == &"CLASH_START" and local_slot in [source, target]:
		counts.locks += 1
	elif event == &"CLASH_LOSS" and source == local_slot:
		counts.wins += 1


func create_block() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "MatchStats"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", GameBalance.get_int("stats_column_gap"))
	grid.add_theme_constant_override("v_separation", GameBalance.get_int("stats_row_gap"))
	for text: String in [
		"Trúng đòn: %d" % counts.hits, "Sườn / lưng: %d" % counts.sides,
		"Gạt thành công: %d" % counts.parries, "Phản đòn: %d" % counts.counters,
		"Hổ lao trúng: %d" % counts.dashes, "Thắng khóa sừng: %d / %d" % [counts.wins, counts.locks],
		"Bị trúng đòn: %d" % counts.received
	]:
		var label := Label.new()
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", GameBalance.get_int("stats_font_size"))
		grid.add_child(label)
	return grid
