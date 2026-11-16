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
	for row: Array in [
		["Trúng đòn", str(counts.hits)], ["Sườn / lưng", str(counts.sides)],
		["Gạt thành công", str(counts.parries)], ["Phản đòn", str(counts.counters)],
		["Hổ lao trúng", str(counts.dashes)], ["Thắng khóa sừng", "%d / %d" % [counts.wins, counts.locks]],
		["Bị trúng đòn", str(counts.received)]
	]:
		for column in 2:
			var label := Label.new()
			label.text = row[column]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if column == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			label.add_theme_color_override("font_color", SettingsControls.MUTED if column == 0 else ControlsDiagram.PAPER)
			label.add_theme_font_size_override("font_size", GameBalance.get_int("stats_font_size"))
			grid.add_child(label)
	return grid
