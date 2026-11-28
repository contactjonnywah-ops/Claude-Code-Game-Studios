class_name Game
extends Node3D
## Groundshift: three rooms; the dark panel you shoot becomes the ground.
## Implements design/game-brief.md.
##
## States and transitions (the only ones allowed):
##   TITLE   -> PLAY     on confirm
##   PLAY    -> PAUSE    on pause, or the mouse being freed
##   PAUSE   -> PLAY     on pause or confirm
##   PLAY    -> DEAD     on a lethal landing
##   DEAD    -> PLAY     after respawn_time (back to the room's start)
##   PLAY    -> RESULTS  on walking through the exit
##   RESULTS -> PLAY     on confirm (a fresh run)

enum State { TITLE, PLAY, PAUSE, DEAD, RESULTS }

const TRANSITIONS := {
	State.TITLE: [State.PLAY],
	State.PLAY: [State.PAUSE, State.DEAD, State.RESULTS],
	State.PAUSE: [State.PLAY],
	State.DEAD: [State.PLAY],
	State.RESULTS: [State.PLAY],
}

## Facing +z, into the rooms.
const START_YAW := PI
## The camera's field of view at rest, degrees (a fall widens it).
const BASE_FOV := 80.0

var state := State.TITLE
var tuning: Tuning
var level: LevelData
var mats: SurfaceMaterials
var player: GravityPlayer
var gun: GravityGun
var cube: GravityCube
var door: ExitDoor
var audio: AudioDirector
var hud: Hud
var camera: Camera3D
var env: Environment
var built: LevelBuilder

var room := 0
var deaths := 0
var run_time := 0.0
var plate_down := false
var low_spec := false
var _dead_timer := 0.0
var _fire_pressed := false
var _switch_pressed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.register()
	tuning = Tuning.load_file()
	level = LevelData.load_file()
	mats = SurfaceMaterials.create(int(tuning.num("seed")))
	var world := Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	_build_environment(world)
	built = LevelBuilder.build(level, mats, world)

	cube = GravityCube.new()
	cube.name = "Crate"
	cube.setup(tuning)
	var cube_mesh := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3.ONE * tuning.num("cube_size")
	cube_mesh.mesh = cm
	cube_mesh.material_override = mats.cube
	cube.add_child(cube_mesh)
	cube.position = level.cube_start
	world.add_child(cube)

	door = ExitDoor.new()
	door.name = "ExitDoor"
	door.setup(level.door, mats.door, tuning.num("door_speed"))
	world.add_child(door)

	player = GravityPlayer.new()
	player.name = "Player"
	player.setup(tuning)
	world.add_child(player)

	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.near = 0.05
	camera.far = 150.0
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	world.add_child(camera)
	camera.current = true

	gun = GravityGun.new()
	gun.setup(player, cube, tuning, mats, world)
	camera.add_child(gun)

	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup(tuning, cube)
	_connect_sounds()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)

	_new_run()
	_enter(State.TITLE)
	if "--low" in OS.get_cmdline_user_args():
		_set_low_spec(true)


# ---- State machine ---------------------------------------------------------------

## Moves to [param next]; asserts the transition is in [constant TRANSITIONS].
func _enter(next: State) -> void:
	if next != state:
		assert(next in TRANSITIONS[state], "Illegal transition %s -> %s" % [state, next])
	state = next
	get_tree().paused = state != State.PLAY and state != State.DEAD
	player.active = state == State.PLAY
	gun.visible = state != State.TITLE
	var capture := state == State.PLAY or state == State.DEAD
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	hud.screen = {
		State.TITLE: Hud.Screen.TITLE, State.PLAY: Hud.Screen.PLAY, State.PAUSE: Hud.Screen.PAUSE,
		State.DEAD: Hud.Screen.DEAD, State.RESULTS: Hud.Screen.RESULTS,
	}[state]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		audio.set_muted(not audio.is_muted())
	if event.is_action_pressed(&"low_spec"):
		_set_low_spec(not low_spec)
	match state:
		State.TITLE:
			if event.is_action_pressed(&"confirm"):
				audio.start_ambience()
				_enter(State.PLAY)
		State.RESULTS:
			if event.is_action_pressed(&"confirm") and not event.is_action_pressed(&"jump"):
				_new_run()
				_enter(State.PLAY)
		State.PAUSE:
			if event.is_action_pressed(&"pause") or event.is_action_pressed(&"fire"):
				_enter(State.PLAY)
		State.PLAY:
			if event.is_action_pressed(&"pause"):
				_enter(State.PAUSE)
			elif event.is_action_pressed(&"restart_room"):
				_respawn()
			elif event.is_action_pressed(&"jump"):
				player.request_jump()
			elif event.is_action_pressed(&"fire"):
				_fire_pressed = true
			elif event.is_action_pressed(&"switch_mode"):
				_switch_pressed = true


func _notification(what: int) -> void:
	# Freeing the mouse (alt-tab, Esc in a browser) pauses the game.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAY:
		_enter(State.PAUSE)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_dead_timer -= delta
		if _dead_timer <= 0.0:
			_respawn()
			_enter(State.PLAY)
		_sync_hud()
		return
	if state != State.PLAY:
		return
	run_time += delta
	var up := player.knocked <= 0.0 # on the floor, the gun hangs idle
	gun.physics_update(delta, _fire_pressed and up, up and Input.is_action_pressed(&"fire"), _switch_pressed and up)
	_fire_pressed = false
	_switch_pressed = false

	var now := level.room_at(player.global_position.z, room)
	while room < now: # a new room is a checkpoint; room 3 puts the crate back where it starts
		room += 1
		audio.set_space(level.rooms[room]["space"])
		audio.play(&"chime", -6.0)
		if room == 2:
			cube.reset_to(level.cube_start)
	# Out of the level (clipped through something): the player dies, the crate goes back.
	var margin := tuning.num("bounds_margin")
	if level.out_of_bounds(player.global_position, margin):
		player.active = false
		_on_died(player.speed())
		return
	if level.out_of_bounds(cube.global_position, margin):
		gun.reset()
		cube.reset_to(level.cube_start)
	var player_rests := player.grounded and player.up().dot(level.plate_up) > 0.7
	var pressed := level.presses_plate(cube.global_position, cube.rests_on(level.plate_up)) \
		or level.presses_plate(player.global_position, player_rests)
	if pressed != plate_down:
		plate_down = pressed
		mats.plate.emission = SurfaceMaterials.PLATE_ON if pressed else SurfaceMaterials.PLATE_OFF
		mats.plate.albedo_color = mats.plate.emission
		audio.play_at(&"plate_on" if pressed else &"plate_off", level.plate_pad.center)
		door.set_open(pressed)
	if player.global_position.z > level.win_z:
		hud.result_text = "Exit reached: %d s, %d death%s" % [roundi(run_time), deaths, "" if deaths == 1 else "s"]
		audio.play(&"win", -2.0)
		_enter(State.RESULTS)
	_sync_hud()


func _process(delta: float) -> void:
	if state == State.TITLE:
		var t := Time.get_ticks_msec() / 1000.0
		camera.global_position = level.title_camera_position + Vector3(sin(t * 0.2) * 1.5, 0, 0)
		camera.look_at(level.title_camera_target)
	else:
		camera.global_position = player.eye_position_interpolated()
		camera.quaternion = player.cam_q * player.body_offset() \
			* Quaternion(Vector3.RIGHT, gun.kick() * 0.07) # the shot jolts the view up
		var fov := BASE_FOV + tuning.num("fall_fov_kick") * player.rush * player.rush
		camera.fov = lerpf(camera.fov, fov, GravityMath.blend(6.0, delta))
	var slide := cube.slide_speed if state == State.PLAY else 0.0
	audio.follow(player.speed() if state == State.PLAY and not player.grounded else 0.0, tuning.num("lethal_speed"),
		gun.beam_on, gun.mode == GravityGun.Mode.TRACTION, slide, delta)


func _sync_hud() -> void:
	hud.room_text = "%s of %d" % [level.rooms[room]["name"], level.rooms.size()]
	hud.deaths = deaths
	hud.traction = gun.mode == GravityGun.Mode.TRACTION
	hud.aim = gun.aim
	hud.lock = gun.lock
	hud.holding = gun.holding
	hud.hurt = player.hurt
	hud.rush = player.rush
	hud.deadly = player.speed() > tuning.num("lethal_speed") and not player.grounded
	hud.muted = audio.is_muted()


# ---- Runs and rooms ----------------------------------------------------------------

func _new_run() -> void:
	room = 0
	deaths = 0
	run_time = 0.0
	_respawn()


## Back to the start of the room you are in, the floor as the ground.
func _respawn() -> void:
	set_world_gravity(Vector3.DOWN)
	audio.set_space(level.rooms[room]["space"])
	player.spawn(level.rooms[room]["start"], START_YAW)
	gun.reset()
	cube.reset_to(level.cube_start)
	door.snap_closed()
	plate_down = false
	mats.plate.emission = SurfaceMaterials.PLATE_OFF
	mats.plate.albedo_color = SurfaceMaterials.PLATE_OFF
	camera.quaternion = player.cam_q


## Points the physics space's gravity along [param down]: the crate falls that way.
func set_world_gravity(down: Vector3) -> void:
	var space := get_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, down.normalized())
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, tuning.num("gravity"))


func _on_died(speed: float) -> void:
	if state == State.DEAD: # the body can hit again on its way down; one death is enough
		return
	deaths += 1
	gun.reset()
	audio.play(&"death", 2.0)
	_dead_timer = tuning.num("respawn_time")
	_enter(State.DEAD)


func _connect_sounds() -> void:
	player.gravity_changed.connect(func(down: Vector3) -> void:
		set_world_gravity(down)
		audio.play(&"shift", -3.0))
	player.died.connect(_on_died)
	player.landed.connect(func(speed: float, severity: float) -> void:
		if severity > tuning.num("hurt_ratio"):
			audio.play(&"hard_land", linear_to_db(0.5 + 0.5 * severity))
		else:
			audio.play(&"land", linear_to_db(0.25 + 0.75 * severity), 1.1 - 0.2 * severity))
	player.jumped.connect(func() -> void: audio.play(&"jump", -8.0))
	player.knocked_down.connect(func(seconds: float) -> void:
		audio.play(&"hard_land", linear_to_db(clampf(seconds / tuning.num("knockdown_max"), 0.4, 1.0)), 0.9))
	player.footstep.connect(func(on_crate: bool) -> void:
		audio.play(&"crate_step" if on_crate else &"step", -10.0, 1.0))
	gun.shot.connect(func(grip: bool, where: Vector3) -> void:
		audio.play(&"shot" if grip else &"dud", 0.0 if grip else -6.0)
		if grip:
			audio.play_at(&"impact", where, 2.0))
	gun.mode_changed.connect(func(_m: GravityGun.Mode) -> void: audio.play(&"switch", -6.0))
	gun.locked.connect(func() -> void: audio.play(&"lock", -4.0))
	gun.released.connect(func() -> void: audio.play(&"release", -6.0))
	cube.impacted.connect(func(speed: float, where: Vector3) -> void:
		var v := clampf(speed / 10.0, 0.05, 1.0)
		audio.play_at(&"crate", where, linear_to_db(v), 1.15 - 0.3 * v))
	door.started.connect(func(_opening: bool) -> void: audio.play_at(&"door", level.door.center, -2.0))


# ---- Look ------------------------------------------------------------------------

func _build_environment(world: Node3D) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0f14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe8f5")
	env.ambient_light_energy = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	# Light bouncing off white panels fills the chambers: the clean, bright test-lab look.
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.35
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)


## Low-spec mode: half resolution, no shadows, no screen-space effects.
func _set_low_spec(on: bool) -> void:
	low_spec = on
	get_viewport().scaling_3d_scale = 0.5 if on else 1.0
	env.ssao_enabled = not on
	env.glow_enabled = not on
	env.sdfgi_enabled = not on
	env.ambient_light_energy = 0.9 if on else 0.15
	for i in built.lamps.size():
		built.lamps[i].shadow_enabled = (not on) and i % 2 == 0
