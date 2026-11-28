extends GdUnitTestSuite
## SfxSynth: every sound is in range, deterministic, and the loops are seamless.


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	return r


func _peak(b: PackedFloat32Array) -> float:
	var m := 0.0
	for s in b:
		m = maxf(m, absf(s))
	return m


func test_one_shots_are_non_silent_and_within_range() -> void:
	var r := _rng()
	for b: PackedFloat32Array in [SfxSynth.footstep(r), SfxSynth.land(r), SfxSynth.death(r),
			SfxSynth.crate_impact(r, 1), SfxSynth.gravity_shot(r), SfxSynth.gravity_impact(r), SfxSynth.gravity_shift(r),
			SfxSynth.door_motor(r, 1.2), SfxSynth.chime(), SfxSynth.win(),
			SfxSynth.distant_machinery(r, 0), SfxSynth.distant_machinery(r, 1), SfxSynth.distant_machinery(r, 2)]:
		assert_int(b.size()).is_greater(0)
		assert_float(_peak(b)).is_between(0.3, 1.0)


func test_same_seed_gives_same_sound() -> void:
	assert_array(Array(SfxSynth.crate_impact(_rng(), 0))).is_equal(Array(SfxSynth.crate_impact(_rng(), 0)))


func test_footstep_length_is_short() -> void:
	assert_int(SfxSynth.footstep(_rng()).size()).is_equal(int(0.22 * SfxSynth.RATE))


func test_loops_join_without_a_jump() -> void:
	var r := _rng()
	for b: PackedFloat32Array in [SfxSynth.wind_loop(r), SfxSynth.beam_loop(r), SfxSynth.scrape_loop(r), SfxSynth.room_tone(r),
			SfxSynth.ambient_pad(r), SfxSynth.danger_loop()]:
		# The step across the loop point is no bigger than typical steps inside it.
		var typical := 0.0
		for i in range(1, b.size()):
			typical = maxf(typical, absf(b[i] - b[i - 1]))
		assert_float(absf(b[0] - b[b.size() - 1])).is_less_equal(typical)


func test_to_stream_is_16_bit_and_loops_when_asked() -> void:
	var b := SfxSynth.chime()
	var s := SfxSynth.to_stream(b, true)
	assert_int(s.data.size()).is_equal(b.size() * 2)
	assert_int(s.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(s.loop_end).is_equal(b.size())
	assert_int(SfxSynth.to_stream(b, false).loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
