class_name DataFile
extends RefCounted
## Reads the JSON config files under res://data/.


## Parsed Dictionary at `path`, or an empty Dictionary when the file is missing or not an object.
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
