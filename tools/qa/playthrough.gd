extends SceneTree
## Plays Groundshift start to exit through the real physics, the way a player would:
## aim, shoot, walk, carry the crate. Proves the level is solvable under real gravity,
## checks a lethal fall kills, and saves screenshots as QA evidence.
##
## Run (needs a display for screenshots; headless runs skip them):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --fixed-fps 60 --disable-vsync \
##       --script res://tools/qa/playthrough.gd
## Exit code 0 means every step passed.

const EVIDENCE := "res://production/qa/evidence/"

var game: Game
var failures: Array[String] = []
var shots := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	await _snap("01_title")
	_press(&"confirm")
	await _frames(40)
	_check(game.state == Game.State.PLAY, "title -> play")

	# ---- Room 1: over the wall by walking on the ceiling ----
	await _snap("02_room1_start")
	# Nose against the back wall: the gun must stay whole, not sink into it.
	await _aim_at(Vector3(0, 1.05, -14))
	Input.action_press(&"move_forward")
	await _frames(60)
	Input.action_release(&"move_forward")
	await _frames(10)
	await _snap("02b_gun_against_wall")
	game.player.spawn(game.level.rooms[0]["start"], Game.START_YAW)
	await _frames(10)
	await _shoot_at(Vector3(0, 9, -11.5))
	await _until_grounded("land on room 1 ceiling")
	_check(game.player.gdir.dot(Vector3.UP) > 0.99, "gravity points at the ceiling")
	await _snap("03_room1_ceiling")
	await _walk_to(Vector3(0, 8.4, -4.5))
	await _shoot_at(Vector3(0, 0, -4.5))
	await _until_grounded("drop back to the floor past the wall")
	_check(game.state == Game.State.PLAY and game.deaths == 0, "a 9 m fall is survivable")
	await _walk_to(Vector3(0, 0.6, 0.5))
	_check(game.room == 1, "reached room 2")

	# ---- Room 2: up the shaft by wall, ceiling, ledge ----
	await _aim_at(Vector3(-2, 22, 5))
	await _frames(4)
	_check(game.gun.aim.get("lethal", false), "the 21 m shaft ceiling reads as a deadly fall")
	await _snap("04_room2_deadly_aim")
	await _shoot_at(Vector3(-6, 3, 5))
	await _snap("04b_gravity_shot")
	await _until_grounded("land on the shaft wall")
	await _walk_to(Vector3(-5.4, 19.5, 5))
	await _shoot_at(Vector3(-2, 22, 5))
	await _until_grounded("land on the shaft ceiling")
	await _snap("05_room2_ceiling")
	await _walk_to(Vector3(4, 21.4, 5))
	await _shoot_at(Vector3(4, 16, 5))
	await _until_grounded("drop to the ledge")
	_check(game.player.global_position.y > 15.9, "standing on the ledge")
	await _walk_to(Vector3(4, 16.6, 13.5))
	_check(game.room == 2, "reached room 3")

	# ---- Room 3: crate to the ceiling, over the tube, drop it on the plate ----
	await _frames(30)
	await _shoot_at(Vector3(0, 25, 17))
	await _until_grounded("land on room 3 ceiling")
	await _frames(90) # the crate falls up too
	_check(game.cube.global_position.y > 23.5, "the crate fell to the ceiling with you")
	_press(&"switch_mode")
	await _frames(2)
	await _aim_at(game.cube.global_position)
	Input.action_press(&"fire")
	var t := 0
	while not game.gun.holding and t < 240:
		await _aim_at(game.cube.global_position)
		t += 1
	_check(game.gun.holding, "traction locks the crate")
	await _snap("06_room3_carry")
	await _walk_to(Vector3(4, 24.4, 19.6), true)
	await _aim_flat(0.0)
	await _frames(60)
	Input.action_release(&"fire")
	await _frames(60)
	_check(game.level.plate_zone.contains(Vector3(game.cube.global_position.x, 16.5, game.cube.global_position.z)),
		"the crate rests on the ceiling over the plate")
	_press(&"switch_mode")
	await _frames(2)
	await _snap("07_room3_crate_over_tube")
	await _shoot_at(Vector3(0, 16, 20))
	await _until_grounded("drop back to the room 3 floor")
	await _frames(120)
	_check(game.plate_down, "the crate dropped through the tube onto the plate")
	_check(game.door.open, "the exit door opened")
	await _frames(60)
	await _aim_at(Vector3(-2, 17, 27))
	await _frames(2)
	await _snap("08_door_open")
	await _walk_to(Vector3(-2, 16.6, 27.5))
	await _frames(5)
	_check(game.state == Game.State.RESULTS, "walked out of the exit")
	await _snap("09_results")

	# ---- A lethal fall kills: new run, room 2, straight up the shaft ----
	_press(&"confirm")
	await _frames(5)
	game.room = 1
	game._respawn()
	await _frames(30)
	var d0 := game.deaths
	await _shoot_at(Vector3(-2, 22, 5))
	var w := 0
	var snapped := false
	while game.state != Game.State.DEAD and w < 600:
		await _frames(1)
		w += 1
		if not snapped and game.player.global_position.y > 17.0:
			snapped = true
			_check(game.player.rush > 0.5 and game.hud.deadly, "a deadly fall rushes and reads as deadly")
			await _snap("09b_falling_rush")
	_check(game.deaths == d0 + 1, "a 21 m fall kills")
	await _frames(10)
	await _snap("10_death")
	await _frames(int(game.tuning.num("respawn_time") * Engine.physics_ticks_per_second) + 40)
	_check(game.state == Game.State.PLAY and game.room == 1, "respawned at the room 2 start")

	# ---- Flipping gravity just before a deadly landing does not save you ----
	await _frames(30)
	d0 = game.deaths
	await _shoot_at(Vector3(-2, 22, 5))
	w = 0
	while game.player.global_position.y < 19.0 and w < 600:
		await _frames(1)
		w += 1
	await _shoot_at(Vector3(-6, 20, 5)) # the shaft wall: gravity turns sideways
	w = 0
	while game.state != Game.State.DEAD and w < 240:
		await _frames(1)
		w += 1
	_check(game.deaths == d0 + 1, "a gravity flip near the ceiling still hits it at a deadly speed")
	await _frames(int(game.tuning.num("respawn_time") * Engine.physics_ticks_per_second) + 40)

	# ---- A jump pressed just before touchdown is kept and fires on landing ----
	await _until_grounded("stand on the room 2 floor")
	var jumps := [0]
	game.player.jumped.connect(func() -> void: jumps[0] += 1)
	game.player.request_jump()
	await _frames(10)
	w = 0
	while not (game.player.velocity.dot(game.player.gdir) > 0.0 and game.player.global_position.y < 0.75) and w < 240:
		await _frames(1)
		w += 1
	game.player.request_jump() # still in the air: only the buffer keeps it
	await _frames(30)
	_check(jumps[0] == 2, "a jump pressed just before landing fires on touchdown")

	# ---- A short hop onto a new floor, before the body turns upright, knocks you down ----
	await _walk_to(Vector3(-5.2, 0.6, 5))
	await _shoot_at(Vector3(-6, 3, 5))
	w = 0
	while game.player.knocked <= 0.0 and w < 60:
		await _frames(1)
		w += 1
	_check(game.player.knocked > 0.0, "landing on a wall half a metre away knocks you down")
	await _frames(15)
	await _snap("11_knocked_down")
	var before := game.player.global_position
	Input.action_press(&"move_forward")
	await _frames(20)
	Input.action_release(&"move_forward")
	_check(game.player.global_position.distance_to(before) < 0.1, "you cannot walk while knocked down")
	await _frames(int(game.tuning.num("knockdown_max") * Engine.physics_ticks_per_second) + 10)
	_check(game.player.knocked <= 0.0 and game.player.grounded, "you get back up")

	print("PLAYTHROUGH: %d checks failed, %d screenshots" % [failures.size(), shots])
	for f in failures:
		print("  FAIL: ", f)
	quit(1 if failures.size() > 0 else 0)


# ---- Driving helpers ------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		if game.state == Game.State.PAUSE: # the window lost focus (someone using the machine): play on
			game._enter(Game.State.PLAY)
		await physics_frame


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Turns the view (inside the player's gravity frame) to look at [param target].
func _aim_at(target: Vector3) -> void:
	var p := game.player
	var d := (target - p.eye_position()).normalized()
	var local := p.view.base.inverse() * d
	p.view.pitch = clampf(asin(clampf(local.y, -1, 1)), -ViewFrame.PITCH_LIMIT, ViewFrame.PITCH_LIMIT)
	p.view.yaw = atan2(-local.x, -local.z)
	await physics_frame


func _aim_flat(pitch: float) -> void:
	game.player.view.pitch = pitch
	await physics_frame


func _shoot_at(target: Vector3) -> void:
	await _aim_at(target)
	await _frames(2)
	game._fire_pressed = true
	await _frames(2)


func _until_grounded(what: String) -> void:
	await _frames(6)
	var t := 0
	while (not game.player.grounded or game.player.knocked > 0.0) and t < 600: # land, and get back up
		await _frames(1)
		t += 1
	await _frames(30)
	_check(game.player.grounded and game.state == Game.State.PLAY, what)
	print("  ok-ish: %s at %s (deaths %d)" % [what, game.player.global_position.snapped(Vector3.ONE * 0.01), game.deaths])


## Walks (in the plane of the current ground) until within 0.35 m of [param target].
## With [param keep_pitch], the look stays level so a carried crate stays in front.
func _walk_to(target: Vector3, keep_pitch: bool = false) -> void:
	var p := game.player
	var t := 0
	while t < 1200:
		if game.state != Game.State.PLAY:
			Input.action_release(&"move_forward")
			return
		var off := target - p.global_position
		off -= p.gdir * off.dot(p.gdir)
		if off.length() < 0.35:
			break
		var local := p.view.base.inverse() * off.normalized()
		p.view.yaw = atan2(-local.x, -local.z)
		if keep_pitch:
			p.view.pitch = 0.0
		Input.action_press(&"move_forward")
		await physics_frame
		t += 1
	Input.action_release(&"move_forward")
	await _frames(20)
	if t >= 1200:
		_check(false, "walk to %s (stuck at %s)" % [target, p.global_position])


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	img.save_png(EVIDENCE + "groundshift_" + name + ".png")
	shots += 1
