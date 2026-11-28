class_name SfxSynth
extends RefCounted
## Synthesises every sound in the game from noise, filters and damped resonances.
##
## Pure functions: each returns mono samples in -1..1 at [constant RATE]. Physical
## models where it matters: the crate is a hollow steel box (inharmonic modes that
## decay at different rates), footsteps are a heel thump plus filtered grit, wind is
## band-passed noise. Loops are cross-faded so they repeat without a click.
##
## Usage:
## [codeblock]
## var rng := RandomNumberGenerator.new()
## var samples := SfxSynth.crate_impact(rng, 0)
## var stream := SfxSynth.to_stream(samples, false)
## [/codeblock]

## Sample rate of everything made here, Hz.
const RATE := 32000


# ---- Sounds -------------------------------------------------------------------------

## A boot on a steel-panelled floor: heel, then toe, and the panel answering.
static func footstep(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.22)
	var k := rng.randf_range(0.9, 1.1)
	_mix(b, _shape(_sweep(0.1, 130.0 * k, 60.0), 0.002, 0.025), 0.55, 0.0)
	_mix(b, _shape(_bandpass(_noise(rng, 0.04), 2600.0 * k, 1.4), 0.0005, 0.008), 0.5, 0.0)
	var toe := rng.randf_range(0.04, 0.06)
	_mix(b, _shape(_bandpass(_noise(rng, 0.04), 1900.0 * k, 1.2), 0.001, 0.01), 0.3, toe)
	_mix(b, _shape(_sweep(0.06, 110.0 * k, 70.0), 0.002, 0.015), 0.25, toe)
	_mix(b, _modal(0.2, [310.0 * k, 520.0 * k, 870.0 * k, 1240.0 * k], [0.05, 0.035, 0.025, 0.015], [1.0, 0.6, 0.4, 0.25], rng), 0.18, 0.002)
	_mix(b, _shape(_highpass(_bandpass(_noise(rng, 0.1), 5000.0, 0.8), 2500.0), 0.01, 0.03), 0.08, 0.01)
	return _normalize(b, 0.8)


## A boot on the hollow crate: the step plus a dull ring of the box.
static func crate_step(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := footstep(rng)
	_mix(b, _modal(0.22, [240.0, 410.0, 655.0, 980.0], [0.09, 0.06, 0.04, 0.03], [1.0, 0.6, 0.4, 0.25], rng), 0.25, 0.0)
	return _normalize(b, 0.8)


## A landing on the feet: two boots strike, the floor panel booms, knees and gear take it.
static func land(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.7)
	for foot in 2:
		var at := foot * rng.randf_range(0.012, 0.025)
		_mix(b, _shape(_sweep(0.3, 100.0, 40.0), 0.002, 0.07), 0.8, at)
		_mix(b, _shape(_bandpass(_noise(rng, 0.05), 2200.0, 1.0), 0.0005, 0.01), 0.5, at)
	_mix(b, _modal(0.6, [92.0, 141.0, 233.0, 377.0, 610.0], [0.25, 0.18, 0.12, 0.08, 0.05], [1.0, 0.7, 0.5, 0.35, 0.2], rng), 0.5, 0.0)
	_mix(b, _shape(_lowpass(_lowpass(_noise(rng, 0.3), 500.0), 500.0), 0.01, 0.08), 1.0, 0.03)
	_mix(b, _shape(_bandpass(_noise(rng, 0.25), 1200.0, 0.6), 0.02, 0.06), 0.15, 0.04)
	_mix(b, _modal(0.3, [820.0, 1310.0, 1975.0, 2630.0], [0.05, 0.04, 0.03, 0.02], [1.0, 0.7, 0.5, 0.3], rng), 0.1, 0.02)
	_drive(b, 1.3)
	return _normalize(b, 0.9)


## A landing that hurts: a heavier thud with a crunch in it.
static func hard_land(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := land(rng)
	b.resize(int(0.8 * RATE))
	_mix(b, _shape(_sweep(0.6, 70.0, 30.0), 0.002, 0.16), 0.9, 0.0)
	_mix(b, _crackle(rng, 0.2, 140.0, 1800.0), 0.5, 0.01)
	return _normalize(b, 0.95)


## The fall that kills: a deep impact and a long crunch.
static func death(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := hard_land(rng)
	b.resize(int(1.4 * RATE))
	_mix(b, _shape(_sweep(1.2, 55.0, 24.0), 0.003, 0.3), 1.0, 0.0)
	_mix(b, _shape(_lowpass(_noise(rng, 1.0), 300.0), 0.002, 0.25), 1.0, 0.0)
	_mix(b, _crackle(rng, 0.35, 260.0, 1400.0), 0.7, 0.02)
	return _normalize(b, 1.0)


## The crate hitting something: a hollow steel box rings in its own modes.
static func crate_impact(rng: RandomNumberGenerator, variant: int) -> PackedFloat32Array:
	var f0: float = [148.0, 163.0, 181.0][variant % 3]
	var ratios := [1.0, 1.59, 2.14, 2.83, 3.91, 5.07, 6.4]
	var freqs: Array = []
	for r: float in ratios:
		freqs.append(f0 * r * rng.randf_range(0.98, 1.02))
	var b := _buf(1.0)
	_mix(b, _modal(1.0, freqs, [0.42, 0.3, 0.22, 0.15, 0.1, 0.07, 0.05], [1.0, 0.75, 0.6, 0.45, 0.35, 0.25, 0.18], rng), 0.7, 0.0)
	_mix(b, _shape(_lowpass(_noise(rng, 0.03), 3500.0), 0.0003, 0.005), 1.0, 0.0)
	_mix(b, _shape(_sweep(0.2, 90.0, 55.0), 0.001, 0.04), 0.9, 0.0)
	return _normalize(b, 0.9)


## The gravity shot: a short charge, then a driven sub-bass slam, a crack and a rumbling tail.
static func gravity_shot(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(1.8)
	var charge := _sweep(0.07, 180.0, 900.0, 3)
	_envelope(charge, 0.06, 0.0, 0.01)
	_mix(b, charge, 0.25, 0.0)
	const HIT := 0.07
	_mix(b, _shape(_sweep(0.9, 110.0, 28.0, 2), 0.002, 0.3), 1.4, HIT)
	_mix(b, _shape(_bandpass(_noise(rng, 0.12), 1800.0, 0.7), 0.0005, 0.03), 0.9, HIT)
	_mix(b, _shape(_lowpass(_lowpass(_noise(rng, 1.6), 220.0), 220.0), 0.01, 0.5), 3.0, HIT)
	_mix(b, _shape(_sweep(0.5, 700.0, 160.0), 0.003, 0.12), 0.25, HIT + 0.01)
	_drive(b, 2.2)
	return _normalize(b, 0.95)


## A gravity shot landing on a panel: a heavy, distant whump with a metallic ring.
static func gravity_impact(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(1.4)
	_mix(b, _shape(_sweep(0.8, 75.0, 30.0), 0.004, 0.28), 1.2, 0.0)
	_mix(b, _shape(_lowpass(_noise(rng, 0.8), 400.0), 0.003, 0.2), 1.0, 0.0)
	_mix(b, _modal(1.2, [210.0, 347.0, 512.0, 760.0], [0.5, 0.35, 0.25, 0.15], [1.0, 0.6, 0.4, 0.25], rng), 0.2, 0.0)
	_drive(b, 1.6)
	return _normalize(b, 0.9)


## A shot at a surface the gun cannot grip: a dull click and a buzz.
static func dud(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.35)
	_mix(b, _shape(_bandpass(_noise(rng, 0.05), 1500.0, 1.5), 0.0005, 0.01), 0.7, 0.0)
	_mix(b, _shape(_lowpass(_square(0.3, 110.0), 800.0), 0.002, 0.07), 0.35, 0.005)
	return _normalize(b, 0.7)


## Gravity turning over: a sub-bass swell, rumble, and the building groaning.
static func gravity_shift(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(2.2)
	_mix(b, _shape(_sweep(2.0, 40.0, 29.0), 0.25, 0.55), 0.9, 0.0)
	_mix(b, _shape(_lowpass(_lowpass(_noise(rng, 2.0), 140.0), 140.0), 0.15, 0.5), 2.2, 0.0)
	_mix(b, _modal(2.0, [97.0, 151.0, 233.0, 347.0], [0.9, 0.7, 0.5, 0.35], [1.0, 0.7, 0.5, 0.3], rng), 0.15, 0.08)
	_mix(b, _shape(_vibrato(1.0, 262.0, 214.0, 5.5, 0.012), 0.3, 0.3), 0.07, 0.12)
	return _normalize(b, 0.9)


## The gun's selector: two clicks and a servo.
static func mode_switch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.25)
	for at: float in [0.0, 0.07]:
		_mix(b, _shape(_bandpass(_noise(rng, 0.03), 3200.0, 2.0), 0.0003, 0.005), 0.8, at)
	_mix(b, _shape(_sweep(0.12, 900.0, 1350.0), 0.01, 0.04), 0.12, 0.01)
	return _normalize(b, 0.6)


## The traction lock closing on the crate.
static func lock_on(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.7)
	_mix(b, _shape(_sweep(0.6, 420.0, 990.0), 0.02, 0.22), 0.4, 0.0)
	_mix(b, _shape(_sweep(0.6, 630.0, 1485.0), 0.02, 0.18), 0.2, 0.0)
	_mix(b, _shape(_bandpass(_noise(rng, 0.4), 6000.0, 1.0), 0.02, 0.1), 0.12, 0.0)
	return _normalize(b, 0.6)


## The traction beam letting go.
static func release(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.4)
	_mix(b, _shape(_sweep(0.35, 720.0, 240.0), 0.005, 0.11), 0.35, 0.0)
	_mix(b, _shape(_lowpass(_noise(rng, 0.2), 800.0), 0.003, 0.05), 0.4, 0.0)
	return _normalize(b, 0.55)


## Pushing off the floor.
static func jump(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.2)
	_mix(b, _shape(_lowpass(_noise(rng, 0.15), 900.0), 0.005, 0.045), 0.6, 0.0)
	_mix(b, _shape(_sweep(0.1, 95.0, 60.0), 0.002, 0.03), 0.4, 0.0)
	return _normalize(b, 0.6)


## The plate taking weight (on) or letting go (off).
static func plate(rng: RandomNumberGenerator, on: bool) -> PackedFloat32Array:
	var b := _buf(0.8)
	_mix(b, _shape(_sweep(0.2, 150.0 if on else 120.0, 65.0), 0.001, 0.05), 0.9, 0.0)
	_mix(b, _shape(_bandpass(_noise(rng, 0.03), 2600.0, 1.5), 0.0004, 0.007), 0.6, 0.0)
	_mix(b, _modal(0.5, [520.0, 1310.0], [0.12, 0.06], [1.0, 0.5], rng), 0.2, 0.0)
	_mix(b, _bell(0.6, 880.0 if on else 440.0), 0.18, 0.05)
	return _normalize(b, 0.75)


## The exit door: a pneumatic hiss, the motor running its travel, a clunk and a vent.
static func door_motor(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds + 0.45)
	var motor := _buf(seconds + 0.15)
	for i in motor.size():
		var t := float(i) / RATE
		var s := 0.0
		for h in range(1, 9):
			s += sin(TAU * 55.0 * h * t) / h
		motor[i] = s * (0.85 + 0.15 * sin(TAU * 31.0 * t))
	_lowpass(motor, 900.0)
	_envelope(motor, 0.08, seconds - 0.08, 0.15)
	_mix(b, motor, 0.5, 0.0)
	var whine := _sweep(seconds, 380.0, 440.0)
	_envelope(whine, 0.1, seconds - 0.2, 0.1)
	_mix(b, whine, 0.05, 0.0)
	var rattle := _bandpass(_noise(rng, seconds), 1200.0, 1.0)
	_envelope(rattle, 0.1, seconds - 0.2, 0.1)
	_mix(b, rattle, 0.08, 0.0)
	_mix(b, _shape(_sweep(0.3, 120.0, 48.0), 0.001, 0.07), 1.0, seconds)
	_mix(b, _shape(_bandpass(_noise(rng, 0.03), 2000.0, 1.5), 0.0003, 0.008), 0.5, seconds)
	_mix(b, _shape(_highpass(_noise(rng, 0.5), 2500.0), 0.01, 0.12), 0.35, 0.0)
	_mix(b, _shape(_highpass(_noise(rng, 0.4), 3000.0), 0.005, 0.09), 0.3, seconds)
	return _normalize(b, 0.8)


## A checkpoint chime.
static func chime() -> PackedFloat32Array:
	var b := _buf(1.6)
	_mix(b, _bell(1.6, 659.25), 0.6, 0.0)
	_mix(b, _bell(1.4, 987.77), 0.35, 0.09)
	return _normalize(b, 0.6)


## The exit: a rising bell chord.
static func win() -> PackedFloat32Array:
	var b := _buf(3.2)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_mix(b, _bell(2.8, notes[i]), 0.4, i * 0.13)
	return _normalize(b, 0.7)


## Rushing air, for falling; loops.
static func wind_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := 3.0
	var fade := 0.4
	var low := _lowpass(_lowpass(_noise(rng, n + fade), 260.0), 260.0)
	var mid := _bandpass(_noise(rng, n + fade), 520.0, 0.6)
	var hiss := _bandpass(_noise(rng, n + fade), 2400.0, 0.9)
	var b := _buf(n + fade)
	for i in b.size():
		var t := float(i) / RATE
		var gust := 0.75 + 0.25 * sin(TAU * t / n) * sin(TAU * 2.0 * t / n + 1.0)
		b[i] = (low[i] * 2.5 + mid[i] * 1.2 + hiss[i] * 0.25) * gust
	return _normalize(_loopify(b, int(fade * RATE)), 0.7)


## A falling-too-fast warning: six soft pulses a second of a bright two-tone beep; loops.
## Exactly one second of whole cycles, so it repeats without a seam.
static func danger_loop() -> PackedFloat32Array:
	var b := _buf(1.0)
	for i in b.size():
		var t := float(i) / RATE
		var gate := pow(maxf(0.0, sin(PI * fmod(t * 6.0, 1.0))), 3.0)
		b[i] = (sin(TAU * 1200.0 * t) + 0.5 * sin(TAU * 1800.0 * t)) * gate
	return _normalize(b, 0.6)


## The traction beam's hum; loops.
static func beam_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := 1.0
	var fade := 0.1
	var b := _buf(n + fade)
	var hiss := _bandpass(_noise(rng, n + fade), 2000.0, 1.0)
	for i in b.size():
		var t := float(i) / RATE
		var am := 0.8 + 0.2 * sin(TAU * 7.0 * t)
		b[i] = (sin(TAU * 110.0 * t) * 0.6 + sin(TAU * 220.0 * t) * 0.3 + sin(TAU * 333.0 * t) * 0.15) * am + hiss[i] * 0.1
	return _normalize(_loopify(b, int(fade * RATE)), 0.6)


## The crate grinding along a surface; loops.
static func scrape_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := 1.2
	var fade := 0.15
	var a := _bandpass(_noise(rng, n + fade), 1600.0, 1.4)
	var c := _bandpass(_noise(rng, n + fade), 3600.0, 2.0)
	var grain := _lowpass(_noise(rng, n + fade), 25.0)
	_normalize(grain, 1.0)
	var b := _buf(n + fade)
	for i in b.size():
		b[i] = (a[i] + c[i] * 0.5) * (0.55 + 0.45 * absf(grain[i]))
	return _normalize(_loopify(b, int(fade * RATE)), 0.6)


## Something far off in the facility, heard through walls: a clank (variant 0), an air
## vent breathing (1) or a servo whirring to a stop (2). Low-passed: distance eats the highs.
static func distant_machinery(rng: RandomNumberGenerator, variant: int) -> PackedFloat32Array:
	var b := _buf(3.0)
	match variant % 3:
		0:
			var f := rng.randf_range(100.0, 140.0)
			_mix(b, _shape(_lowpass(_noise(rng, 0.05), 900.0), 0.001, 0.02), 0.8, 0.0)
			_mix(b, _modal(2.5, [f, f * 1.56, f * 2.21, f * 3.42], [0.9, 0.6, 0.4, 0.25], [1.0, 0.7, 0.5, 0.3], rng), 0.6, 0.0)
		1:
			var vent := _bandpass(_noise(rng, 2.8), rng.randf_range(450.0, 700.0), 0.5)
			_envelope(vent, 0.7, 0.8, 1.2)
			_mix(b, vent, 1.0, 0.0)
		2:
			var whir := _sweep(1.3, rng.randf_range(80.0, 100.0), rng.randf_range(130.0, 160.0), 4)
			_envelope(whir, 0.15, 0.95, 0.2)
			_mix(b, whir, 0.6, 0.0)
			_mix(b, _shape(_sweep(0.3, 90.0, 45.0), 0.002, 0.08), 0.8, 1.3)
	_lowpass(_lowpass(b, 1500.0), 1500.0)
	return _normalize(b, 0.8)


## A slow, cold synth pad under everything (a spread minor-ninth chord that breathes); loops.
static func ambient_pad(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := 8.0
	var fade := 1.0
	var b := _buf(n + fade)
	var notes := [73.42, 110.0, 174.61, 261.63, 329.63] # D2 A2 F3 C4 E4
	for v in notes.size():
		var f: float = notes[v]
		var ph := rng.randf() * TAU
		var swell := rng.randf() * TAU
		var level := 1.0 / (1.0 + v * 0.35)
		for i in b.size():
			var t := float(i) / RATE
			var amp := (0.6 + 0.4 * sin(TAU * t * (v % 2 + 1) / n + swell)) * level
			# Two slightly detuned voices beat slowly, the octave adds a little air.
			b[i] += (sin(TAU * f * t + ph) + 0.6 * sin(TAU * f * 1.004 * t) + 0.15 * sin(TAU * f * 2.0 * t)) * amp
	_lowpass(b, 1400.0)
	return _normalize(_loopify(b, int(fade * RATE)), 0.5)


## The rooms' air handling and mains hum; loops.
static func room_tone(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := 4.0
	var fade := 0.5
	var brown := _lowpass(_lowpass(_noise(rng, n + fade), 180.0), 180.0)
	var air := _bandpass(_noise(rng, n + fade), 320.0, 0.7)
	var b := _buf(n + fade)
	for i in b.size():
		var t := float(i) / RATE
		# Light-fitting buzz: mains harmonics up to 240 Hz, a little brighter than plain hum.
		b[i] = sin(TAU * 60.0 * t) * 0.05 + sin(TAU * 120.0 * t) * 0.05 + sin(TAU * 180.0 * t) * 0.02 \
			+ sin(TAU * 240.0 * t) * 0.012 + brown[i] * 1.6 + air[i] * 0.35
	return _normalize(_loopify(b, int(fade * RATE)), 0.5)


## Turns samples into a 16-bit stream; with [param loop], one that repeats forever.
static func to_stream(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


# ---- Building blocks ----------------------------------------------------------------

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


static func _noise(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


## A sine gliding from [param f0] to [param f1] Hz (exponentially); [param harmonics] adds overtones.
static func _sweep(seconds: float, f0: float, f1: float, harmonics: int = 1) -> PackedFloat32Array:
	var b := _buf(seconds)
	var phase := 0.0
	var n := b.size()
	for i in n:
		var f := f0 * pow(f1 / f0, float(i) / n)
		phase += TAU * f / RATE
		var s := 0.0
		for h in range(1, harmonics + 1):
			s += sin(phase * h) / h
		b[i] = s
	return b


static func _square(seconds: float, f: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		b[i] = 1.0 if fmod(float(i) * f / RATE, 1.0) < 0.5 else -1.0
	return b


## A sine glide with vibrato of [param depth] (share of pitch) at [param rate] Hz.
static func _vibrato(seconds: float, f0: float, f1: float, rate: float, depth: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var phase := 0.0
	var n := b.size()
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, float(i) / n) * (1.0 + depth * sin(TAU * rate * t))
		phase += TAU * f / RATE
		b[i] = sin(phase) + 0.3 * sin(phase * 2.0)
	return b


## A sum of exponentially decaying sines: how struck objects ring.
static func _modal(seconds: float, freqs: Array, taus: Array, amps: Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(seconds)
	for m in freqs.size():
		var w := TAU * float(freqs[m]) / RATE
		var decay := exp(-1.0 / (float(taus[m]) * RATE))
		var a := float(amps[m]) * rng.randf_range(0.8, 1.0)
		var env := 1.0
		var ph := rng.randf() * TAU
		for i in b.size():
			b[i] += sin(ph + w * i) * a * env
			env *= decay
	return b


## A bell: inharmonic partials, the high ones dying first.
static func _bell(seconds: float, f: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var ratios := [1.0, 2.0, 2.76, 4.07, 5.4]
	var taus := [seconds * 0.5, seconds * 0.32, seconds * 0.2, seconds * 0.12, seconds * 0.08]
	var amps := [1.0, 0.45, 0.35, 0.2, 0.12]
	for m in ratios.size():
		var w := TAU * f * float(ratios[m]) / RATE
		var decay := exp(-1.0 / (float(taus[m]) * RATE))
		var env := float(amps[m])
		for i in b.size():
			b[i] += sin(w * i) * env
			env *= decay
	return b


## Sparse random clicks, filtered: bone and grit.
static func _crackle(rng: RandomNumberGenerator, seconds: float, per_second: float, hz: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var p := per_second / RATE
	for i in b.size():
		if rng.randf() < p:
			b[i] = rng.randf_range(-1.0, 1.0) * (1.0 - float(i) / b.size())
	_bandpass(b, hz, 0.9)
	return _normalize(b, 1.0)


## In place: linear attack, then exponential decay with time constant [param tau].
static func _shape(b: PackedFloat32Array, attack: float, tau: float) -> PackedFloat32Array:
	var a := maxf(1.0, attack * RATE)
	var k := exp(-1.0 / (tau * RATE))
	var env := 1.0
	for i in b.size():
		if i < a:
			b[i] *= i / a
		else:
			env *= k
			b[i] *= env
	return b


## In place: attack, hold and release, linear.
static func _envelope(b: PackedFloat32Array, attack: float, hold: float, rel: float) -> void:
	for i in b.size():
		var t := float(i) / RATE
		var g := 1.0
		if t < attack:
			g = t / attack
		elif t > attack + hold:
			g = maxf(0.0, 1.0 - (t - attack - hold) / rel)
		b[i] *= g


## In place: two-pole low-pass at [param hz] (one-pole twice would be gentler).
static func _lowpass(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y
	return b


static func _highpass(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = b[i] - y
	return b


## In place: RBJ biquad band-pass (constant peak gain) at [param hz] with quality [param q].
static func _bandpass(b: PackedFloat32Array, hz: float, q: float) -> PackedFloat32Array:
	var w := TAU * hz / RATE
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w) / a0
	var a2 := (1.0 - alpha) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in b.size():
		var x := b[i]
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		b[i] = y
	return b


## Adds [param src] times [param gain] into [param dst] from [param at] seconds on.
static func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, at: float) -> void:
	var o := int(at * RATE)
	var n := mini(src.size(), dst.size() - o)
	for i in n:
		dst[o + i] += src[i] * gain


## In place: soft-clips through tanh after [param gain]: thicker, louder-feeling lows.
static func _drive(b: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	_normalize(b, 1.0)
	for i in b.size():
		b[i] = tanh(b[i] * gain)
	return b


## In place: scales so the loudest sample is [param peak].
static func _normalize(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for s in b:
		m = maxf(m, absf(s))
	if m > 0.0:
		var k := peak / m
		for i in b.size():
			b[i] *= k
	return b


## Cross-fades the last [param fade] samples into the start, so the result loops cleanly.
static func _loopify(b: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := b.size() - fade
	var out := b.slice(0, n)
	for i in fade:
		var k := float(i) / fade
		out[i] = b[i] * k + b[n + i] * (1.0 - k)
	return out
