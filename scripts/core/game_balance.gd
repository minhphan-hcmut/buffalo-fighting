class_name GameBalance
extends Node
## Single source for gameplay constants. Modules read data/balance.json only.

const PATH := "res://data/balance.json"
static var values: Dictionary = {}


func _ready() -> void:
	_load_values()


static func _load_values() -> void:
	if not values.is_empty():
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Missing balance data: %s" % PATH)
		return
	values = JSON.parse_string(file.get_as_text())


static func get_number(key: String, fallback: float = 0.0) -> float:
	_load_values()
	return float(values.get(key, fallback))


static func get_int(key: String, fallback: int = 0) -> int:
	_load_values()
	return int(values.get(key, fallback))


static func get_angle(key: String, fallback: float = 0.0) -> float:
	return deg_to_rad(get_number(key, fallback))
