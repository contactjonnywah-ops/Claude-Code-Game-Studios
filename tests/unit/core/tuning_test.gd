extends GdUnitTestSuite
## Tuning: values load from data, with their rationale beside them.


func test_shipped_tuning_uses_real_gravity() -> void:
	assert_float(Tuning.load_file().num("gravity")).is_equal(9.81)


func test_from_dict_reads_value_objects_and_plain_numbers() -> void:
	var t := Tuning.from_dict({ "a": { "value": 2.5, "why": "x" }, "b": 3 })
	assert_float(t.num("a")).is_equal(2.5)
	assert_float(t.num("b")).is_equal(3.0)


func test_set_num_overrides() -> void:
	var t := Tuning.from_dict({ "a": 1 })
	t.set_num("a", 4.0)
	assert_float(t.num("a")).is_equal(4.0)


func test_every_shipped_value_has_a_rationale() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tuning.DEFAULT_PATH))
	for key: String in data:
		assert_str(str(data[key].get("why", ""))).is_not_empty()
