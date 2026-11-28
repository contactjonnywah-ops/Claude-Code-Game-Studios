class_name AudioDirector
extends Node
## Plays the game's sounds: builds the buses (with room reverb), synthesises the
## bank at start, and keeps the loops (wind, beam hum, crate scrape, room tone)
## following the physics.
##
## Usage:
## [codeblock]
## var audio := AudioDirector.new()
## add_child(audio)
## audio.setup(tuning, cube)
## audio.play(&"jump")
## audio.play_at(&"crate", cube.global_position, -6.0)
## [/codeblock]

const SFX_BUS := &"SFX"
const AMBIENCE_BUS := &"Ambience"

var _rng := RandomNumberGenerator.new()
var _bank: Dictionary = {} # StringName -> Array[AudioStreamWAV]
var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
var _next_flat := 0
var _next_spatial := 0
var _wind: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _room: AudioStreamPlayer
var _pad: AudioStreamPlayer
var _scrape: AudioStreamPlayer3D
var _cube: Node3D
var _muted := false
var _verb: AudioEffectReverb
var _distant: AudioStreamPlayer
var _gap := Vector2(5.0, 14.0)
var _next_distant := INF


## Synthesises the sounds and builds the players. [param cube] carries the scrape loop.
func setup(tuning: Tuning, cube: Node3D) -> void:
	_rng.seed = int(tuning.num("seed"))
	_cube = cube
	_build_buses(tuning.num("volume"))
	_build_bank()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_flat.append(p)
	for i in 8:
		var p := AudioStreamPlayer3D.new()
		p.bus = SFX_BUS
		p.unit_size = 4.0
		p.max_distance = 60.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -12.0
		add_child(p)
		_spatial.append(p)
	_wind = _loop(&"wind", SFX_BUS)
	_hum = _loop(&"beam", SFX_BUS)
	_room = _loop(&"room", AMBIENCE_BUS)
	_room.volume_db = -14.0
	_pad = _loop(&"pad", AMBIENCE_BUS)
	_pad.volume_db = -20.0
	_distant = AudioStreamPlayer.new()
	_distant.bus = AMBIENCE_BUS
	add_child(_distant)
	_gap = Vector2(tuning.num("distant_gap_min"), tuning.num("distant_gap_max"))
	_scrape = AudioStreamPlayer3D.new()
	_scrape.stream = _bank[&"scrape"][0]
	_scrape.bus = SFX_BUS
	_scrape.unit_size = 4.0
	_scrape.volume_db = -80.0
	cube.add_child(_scrape)
	_scrape.play()


## Starts the always-on room tone.
func start_ambience() -> void:
	if not _room.playing:
		_room.play()
		_pad.play()
		_next_distant = _rng.randf_range(_gap.x, _gap.y)


## Makes the sound effects ring like the room the player is in: [param space] maps
## [AudioEffectReverb] property names (room_size, wet, predelay_msec, damping) to values.
func set_space(space: Dictionary) -> void:
	for key: String in space:
		_verb.set(key, float(space[key]))


func _process(delta: float) -> void:
	# The rest of the facility: now and then something far off clanks, vents or whirs.
	_next_distant -= delta
	if _next_distant <= 0.0:
		_next_distant = _rng.randf_range(_gap.x, _gap.y)
		_distant.stream = _pick(&"distant")
		_distant.volume_db = _rng.randf_range(-22.0, -14.0)
		_distant.pitch_scale = _rng.randf_range(0.85, 1.1)
		_distant.play()


## Plays [param name] without position.
func play(name: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := _flat[_next_flat]
	_next_flat = (_next_flat + 1) % _flat.size()
	p.stream = _pick(name)
	p.volume_db = volume_db
	p.pitch_scale = pitch * _rng.randf_range(0.97, 1.03)
	p.play()


## Plays [param name] from [param where] in the world.
func play_at(name: StringName, where: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := _spatial[_next_spatial]
	_next_spatial = (_next_spatial + 1) % _spatial.size()
	p.global_position = where
	p.stream = _pick(name)
	p.volume_db = volume_db
	p.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
	p.play()


## Follows the physics each frame: wind with the player's speed, hum with the beam,
## scrape with the crate sliding.
func follow(player_speed: float, beam_on: bool, traction: bool, cube_slide: float, delta: float) -> void:
	var w := clampf((player_speed - 2.0) / 28.0, 0.0, 1.0)
	_set_loop(_wind, w * w * 1.2, delta)
	_wind.pitch_scale = 0.75 + w * 0.6
	_set_loop(_hum, 0.35 if beam_on and traction else 0.0, delta)
	var s := clampf((cube_slide - 0.3) / 4.0, 0.0, 1.0)
	_scrape.volume_db = linear_to_db(maxf(s * 0.8, 0.0001))
	_scrape.pitch_scale = 0.8 + s * 0.5


## Silences everything, or brings it back.
func set_muted(m: bool) -> void:
	_muted = m
	AudioServer.set_bus_mute(0, m)


## Whether sound is muted.
func is_muted() -> bool:
	return _muted


func _set_loop(p: AudioStreamPlayer, target_linear: float, delta: float) -> void:
	var cur := db_to_linear(p.volume_db) if p.playing else 0.0
	var v := lerpf(cur, target_linear, GravityMath.blend(10.0, delta))
	if v < 0.002:
		if p.playing:
			p.stop()
		p.volume_db = -80.0
		return
	if not p.playing:
		p.play()
	p.volume_db = linear_to_db(v)


func _pick(name: StringName) -> AudioStreamWAV:
	var list: Array = _bank[name]
	return list[_rng.randi() % list.size()]


func _loop(name: StringName, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _bank[name][0]
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func _build_buses(volume: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, SFX_BUS)
		AudioServer.set_bus_send(i, &"Master")
		var verb := AudioEffectReverb.new() # steel-and-concrete rooms; set_space tunes it per room
		verb.room_size = 0.72
		verb.damping = 0.35
		verb.spread = 0.8
		verb.predelay_msec = 28.0
		verb.wet = 0.2
		verb.dry = 1.0
		verb.hipass = 0.1
		AudioServer.add_bus_effect(i, verb)
		var limiter := AudioEffectHardLimiter.new()
		AudioServer.add_bus_effect(0, limiter)
	_verb = AudioServer.get_bus_effect(AudioServer.get_bus_index(SFX_BUS), 0)
	if AudioServer.get_bus_index(AMBIENCE_BUS) == -1:
		AudioServer.add_bus()
		var j := AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, AMBIENCE_BUS)
		AudioServer.set_bus_send(j, &"Master")
		var hall := AudioEffectReverb.new() # far-off sounds arrive mostly as echo
		hall.room_size = 0.95
		hall.damping = 0.5
		hall.predelay_msec = 80.0
		hall.wet = 0.6
		hall.dry = 0.5
		AudioServer.add_bus_effect(j, hall)


func _build_bank() -> void:
	var r := _rng
	var many := func(make: Callable, n: int) -> Array:
		var out: Array = []
		for i in n:
			out.append(SfxSynth.to_stream(make.call(i), false))
		return out
	_bank[&"step"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.footstep(r), 8)
	_bank[&"crate_step"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.crate_step(r), 3)
	_bank[&"land"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.land(r), 2)
	_bank[&"hard_land"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.hard_land(r), 2)
	_bank[&"death"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.death(r), 1)
	_bank[&"crate"] = many.call(func(i: int) -> PackedFloat32Array: return SfxSynth.crate_impact(r, i), 3)
	_bank[&"shot"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.gravity_shot(r), 2)
	_bank[&"impact"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.gravity_impact(r), 2)
	_bank[&"dud"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.dud(r), 1)
	_bank[&"shift"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.gravity_shift(r), 1)
	_bank[&"switch"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.mode_switch(r), 1)
	_bank[&"lock"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.lock_on(r), 1)
	_bank[&"release"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.release(r), 1)
	_bank[&"jump"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.jump(r), 2)
	_bank[&"plate_on"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.plate(r, true), 1)
	_bank[&"plate_off"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.plate(r, false), 1)
	_bank[&"door"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.door_motor(r, 1.2), 1)
	_bank[&"chime"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.chime(), 1)
	_bank[&"win"] = many.call(func(_i: int) -> PackedFloat32Array: return SfxSynth.win(), 1)
	_bank[&"wind"] = [SfxSynth.to_stream(SfxSynth.wind_loop(r), true)]
	_bank[&"beam"] = [SfxSynth.to_stream(SfxSynth.beam_loop(r), true)]
	_bank[&"scrape"] = [SfxSynth.to_stream(SfxSynth.scrape_loop(r), true)]
	_bank[&"room"] = [SfxSynth.to_stream(SfxSynth.room_tone(r), true)]
	_bank[&"pad"] = [SfxSynth.to_stream(SfxSynth.ambient_pad(r), true)]
	_bank[&"distant"] = many.call(func(i: int) -> PackedFloat32Array: return SfxSynth.distant_machinery(r, i), 6)
