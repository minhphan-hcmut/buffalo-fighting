class_name GameBalance
extends Node
## Single lookup for every tuning number, read from two files under res://data/:
## - `balance.json`: gameplay rules (movement, combat, clash, arena, timing). Changing
##   these changes how a match plays and must stay identical on host and client.
## - `presentation.json`: look and feel only (camera, animation, VFX, HUD, tutorial,
##   announcer, outro). Changing these never changes a match result.
## A key may live in only one file; duplicates are reported as errors.

const PATH := "res://data/balance.json"
const PRESENTATION_PATH := "res://data/presentation.json"
static var values: Dictionary = {}


func _ready() -> void:
	_load_values()


static func _load_values() -> void:
	if not values.is_empty():
		return
	values = DataFile.load_json(PATH)
	if values.is_empty():
		push_error("Missing balance data: %s" % PATH)
	var presentation := DataFile.load_json(PRESENTATION_PATH)
	if presentation.is_empty():
		push_error("Missing presentation data: %s" % PRESENTATION_PATH)
	for key in presentation:
		if values.has(key):
			push_error("Tuning key '%s' is in both %s and %s" % [key, PATH, PRESENTATION_PATH])
		values[key] = presentation[key]


## Number stored under `key`, or `fallback` when no data file defines it.
static func get_number(key: String, fallback: float = 0.0) -> float:
	_load_values()
	return float(values.get(key, fallback))


## Integer stored under `key`, or `fallback` when no data file defines it.
static func get_int(key: String, fallback: int = 0) -> int:
	_load_values()
	return int(values.get(key, fallback))


## Angle stored in degrees under `key`, returned in radians.
static func get_angle(key: String, fallback: float = 0.0) -> float:
	return deg_to_rad(get_number(key, fallback))
