extends GdUnitTestSuite
## ViewFrame: rolling the view to a new up keeps the look direction.


func _frame(yaw: float, pitch: float) -> ViewFrame:
	var v := ViewFrame.new()
	v.reset(yaw)
	v.pitch = pitch
	return v


func test_reset_looks_along_yaw_with_world_up() -> void:
	var v := _frame(PI, 0.0)
	assert_vector(v.up()).is_equal_approx(Vector3.UP, Vector3.ONE * 0.0001)
	assert_vector(v.forward()).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.0001)


func test_rebase_to_wall_keeps_forward() -> void:
	var v := _frame(0.7, 0.3)
	var before := v.forward()
	v.rebase(Vector3.RIGHT)
	assert_vector(v.up()).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.0001)
	assert_vector(v.forward()).is_equal_approx(before, Vector3.ONE * 0.001)


func test_rebase_to_ceiling_keeps_forward() -> void:
	# Straight overhead is the antiparallel case: the arc has no unique axis.
	var v := _frame(PI, 0.5)
	var before := v.forward()
	v.rebase(Vector3.DOWN)
	assert_vector(v.up()).is_equal_approx(Vector3.DOWN, Vector3.ONE * 0.0001)
	assert_vector(v.forward()).is_equal_approx(before, Vector3.ONE * 0.001)


func test_rebase_to_tilted_ramp_keeps_forward() -> void:
	var v := _frame(-1.2, -0.2)
	var before := v.forward()
	var ramp_up := Vector3(sin(0.45), cos(0.45), 0.0)
	v.rebase(ramp_up)
	assert_vector(v.up()).is_equal_approx(ramp_up, Vector3.ONE * 0.0001)
	assert_vector(v.forward()).is_equal_approx(before, Vector3.ONE * 0.001)


func test_rebase_to_same_up_changes_nothing() -> void:
	var v := _frame(0.4, 0.2)
	v.rebase(Vector3.UP)
	assert_float(v.yaw).is_equal_approx(0.4, 0.00001)
	assert_float(v.pitch).is_equal_approx(0.2, 0.00001)


func test_add_look_clamps_pitch() -> void:
	var v := _frame(0.0, 0.0)
	v.add_look(0.0, 10.0)
	assert_float(v.pitch).is_equal(ViewFrame.PITCH_LIMIT)


func test_flat_has_no_pitch() -> void:
	var v := _frame(0.3, 1.2)
	var f := v.flat() * Vector3.FORWARD
	assert_float(f.dot(v.up())).is_equal_approx(0.0, 0.00001)
