class_name Tuning
extends RefCounted
## Gameplay tuning values, read from [code]assets/data/game_tuning.json[/code].
##
## Every value in the file is an object [code]{ "value": n, "why": "..." }[/code];
## the "why" is the rationale for the number. Nothing in [code]src/[/code] hardcodes a
## gameplay value: it asks this object.

## Where the shipped tuning lives.
const DEFAULT_PATH := "res://assets/data/game_tuning.json"

var _values: Dictionary = {}


## Loads tuning from a JSON file. Fails loudly on a missing or broken file.
static func load_file(path: String = DEFAULT_PATH) -> Tuning:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Tuning file missing or empty: %s" % path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Tuning file is not a JSON object: %s" % path)
	return from_dict(parsed)


## Builds tuning from an already-parsed dictionary (used by tests to inject values).
static func from_dict(data: Dictionary) -> Tuning:
	var t := Tuning.new()
	for key: String in data:
		var entry: Variant = data[key]
		t._values[key] = float(entry["value"]) if entry is Dictionary else float(entry)
	return t


## The value for [param key]. Asserts that the key exists.
func num(key: String) -> float:
	assert(_values.has(key), "Unknown tuning key: %s" % key)
	return _values[key]


## Whether [param key] is defined.
func has(key: String) -> bool:
	return _values.has(key)


## Overrides one value at runtime (debug and tests).
func set_num(key: String, value: float) -> void:
	_values[key] = value
