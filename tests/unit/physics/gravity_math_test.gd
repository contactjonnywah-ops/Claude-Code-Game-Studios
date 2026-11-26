extends GdUnitTestSuite
## GravityMath: falls with quadratic air drag.

const G := 9.81
const MASS := 80.0


func test_impact_speed_without_drag_matches_free_fall() -> void:
	# v = sqrt(2 g h)
	assert_float(GravityMath.impact_speed(10.0, G, MASS, 0.0)).is_equal_approx(sqrt(2.0 * G * 10.0), 0.0001)


func test_impact_speed_with_drag_is_below_free_fall() -> void:
	var k := GravityMath.drag_constant(1.225, 0.55)
	var with_drag := GravityMath.impact_speed(21.0, G, MASS, k)
	assert_float(with_drag).is_less(sqrt(2.0 * G * 21.0))
	assert_float(with_drag).is_greater(18.0)


func test_impact_speed_never_exceeds_terminal() -> void:
	var k := GravityMath.drag_constant(1.225, 0.55)
	var vt := GravityMath.terminal_speed(MASS, G, k)
	assert_float(GravityMath.impact_speed(5000.0, G, MASS, k)).is_less_equal(vt)
	assert_float(GravityMath.impact_speed(5000.0, G, MASS, k)).is_equal_approx(vt, 0.01)


func test_impact_speed_from_above_terminal_slows_toward_terminal() -> void:
	var k := GravityMath.drag_constant(1.225, 0.55)
	var vt := GravityMath.terminal_speed(MASS, G, k)
	var v := GravityMath.impact_speed(50.0, G, MASS, k, vt * 1.5)
	assert_float(v).is_less(vt * 1.5)
	assert_float(v).is_greater(vt)


func test_impact_speed_zero_height_returns_start_speed() -> void:
	assert_float(GravityMath.impact_speed(0.0, G, MASS, 0.3, 4.0)).is_equal(4.0)


func test_impact_speed_matches_numeric_integration() -> void:
	var k := GravityMath.drag_constant(1.225, 0.55)
	var v := 0.0
	var h := 0.0
	var dt := 0.0001
	while h < 15.0:
		v += (G - k / MASS * v * v) * dt
		h += v * dt
	assert_float(GravityMath.impact_speed(15.0, G, MASS, k)).is_equal_approx(v, 0.01)


func test_terminal_speed_of_tuned_player_is_skydiver_like() -> void:
	var k := GravityMath.drag_constant(1.225, 0.55)
	assert_float(GravityMath.terminal_speed(MASS, G, k)).is_between(40.0, 60.0)


func test_terminal_speed_without_drag_is_infinite() -> void:
	assert_float(GravityMath.terminal_speed(MASS, G, 0.0)).is_equal(INF)


func test_jump_speed_reaches_height() -> void:
	var v := GravityMath.jump_speed(G, 0.9)
	assert_float(v * v / (2.0 * G)).is_equal_approx(0.9, 0.0001)


func test_drag_acceleration_opposes_motion_and_scales_with_square() -> void:
	var a1 := GravityMath.drag_acceleration(Vector3(0, -10, 0), 0.4, MASS)
	var a2 := GravityMath.drag_acceleration(Vector3(0, -20, 0), 0.4, MASS)
	assert_float(a1.y).is_greater(0.0)
	assert_float(a2.y / a1.y).is_equal_approx(4.0, 0.0001)


func test_landing_severity_clamps_to_unit_range() -> void:
	assert_float(GravityMath.landing_severity(8.5, 17.0)).is_equal_approx(0.5, 0.0001)
	assert_float(GravityMath.landing_severity(40.0, 17.0)).is_equal(1.0)


func test_is_lethal_boundary_is_exclusive() -> void:
	assert_bool(GravityMath.is_lethal(17.0, 17.0)).is_false()
	assert_bool(GravityMath.is_lethal(17.01, 17.0)).is_true()


func test_blend_is_frame_rate_independent() -> void:
	# Two half steps close the same gap as one full step.
	var one := GravityMath.blend(10.0, 0.1)
	var half := GravityMath.blend(10.0, 0.05)
	assert_float(1.0 - (1.0 - half) * (1.0 - half)).is_equal_approx(one, 0.00001)


func test_shipped_tuning_makes_room_heights_safe_and_shaft_deadly() -> void:
	var t := Tuning.load_file()
	var k := GravityMath.drag_constant(t.num("air_density"), t.num("player_drag_area"))
	var room := GravityMath.impact_speed(9.0 - 1.2, t.num("gravity"), t.num("player_mass"), k)
	var shaft := GravityMath.impact_speed(22.0 - 1.2, t.num("gravity"), t.num("player_mass"), k)
	assert_bool(GravityMath.is_lethal(room, t.num("lethal_speed"))).is_false()
	assert_bool(GravityMath.is_lethal(shaft, t.num("lethal_speed"))).is_true()
