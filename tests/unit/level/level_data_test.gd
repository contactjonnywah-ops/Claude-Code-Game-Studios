extends GdUnitTestSuite
## LevelData and BoxSpec: the shipped rooms load and the trigger zones work.


func test_box_from_corners_gives_centre_and_half() -> void:
	var b := BoxSpec.from_corners([-1, 3, 0, 2, 4, 5])
	assert_vector(b.center).is_equal(Vector3(1, 1, 4.5))
	assert_vector(b.half).is_equal(Vector3(2, 1, 0.5))
	assert_float(b.rot).is_equal(0.0)


func test_box_reads_optional_turn() -> void:
	assert_float(BoxSpec.from_corners([0, 1, 0, 1, 0, 1, -0.45]).rot).is_equal(-0.45)


func test_box_contains_is_strict_inside() -> void:
	var b := BoxSpec.from_corners([0, 2, 0, 2, 0, 2])
	assert_bool(b.contains(Vector3(1, 1, 1))).is_true()
	assert_bool(b.contains(Vector3(2, 1, 1))).is_false()


func test_shipped_level_has_three_rooms_and_ten_panels() -> void:
	var L := LevelData.load_file()
	assert_int(L.rooms.size()).is_equal(3)
	assert_int(L.panels.size()).is_equal(10)
	assert_int(L.walls.size()).is_equal(23)


func test_room_at_advances_and_never_goes_back() -> void:
	var L := LevelData.load_file()
	assert_int(L.room_at(-10.0, 0)).is_equal(0)
	assert_int(L.room_at(5.0, 0)).is_equal(1)
	assert_int(L.room_at(20.0, 0)).is_equal(2)
	assert_int(L.room_at(-10.0, 2)).is_equal(2)


func test_crate_resting_on_the_pad_presses_the_plate() -> void:
	var L := LevelData.load_file()
	assert_bool(L.presses_plate(Vector3(4, 16.5, 23))).is_true()
	assert_bool(L.presses_plate(Vector3(0.5, 16.5, 15))).is_false()


func test_ramp_panel_sits_on_ramp_face() -> void:
	var L := LevelData.load_file()
	var ramp := L.blocks[2]
	var panel := L.panels[9]
	var up := Basis(Vector3.BACK, ramp.rot) * Vector3.UP
	assert_float((panel.center - ramp.center).dot(up)).is_equal_approx(0.27, 0.001)
