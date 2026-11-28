class_name GravityPlayer
extends CharacterBody3D
## The player: a sphere that walks on whatever surface gravity points at, wearing a
## [SuitBody] of torso and legs.
##
## Motion is integrated by hand each physics step: gravity along [member gdir],
## quadratic air drag, feet that grip on the ground and momentum that carries in
## the air. The body's orientation is its own: a gravity shift leaves you as you were,
## and in a fall WASD rolls and pitches you (a weak reflex turns you feet-first when no
## key is held). Landings are judged by speed and by how upright you came down: hard
## or crooked ones knock you down, and the suit goes limp as a ragdoll until it settles;
## past [code]lethal_speed[/code] they kill. Pushing the crate hands it momentum;
## standing on it presses it down with the player's weight.

## Landed safely at [param speed] m/s; [param severity] is 0..1 of lethal.
signal landed(speed: float, severity: float)
## Landed too hard.
signal died(speed: float)
signal jumped
## One footstep; [param on_crate] when standing on the crate.
signal footstep(on_crate: bool)
## Gravity now points along [param down].
signal gravity_changed(down: Vector3)
## Landed off balance or too hard: limp for at least [param seconds].
signal knocked_down(seconds: float)

## Landings slower than this make no sound, m/s.
const QUIET_LANDING := 2.5
## Seconds the view takes to blend from the limp head back to the eye on getting up.
const GETUP_BLEND := 0.4

## Which way things fall (unit vector).
var gdir := Vector3.DOWN
## The body's orientation ([member ViewFrame.base]) and the look inside it.
var view := ViewFrame.new()
## Whether input moves the player.
var active := false
var grounded := false
## How far the view currently dips from a landing, m.
var dip := 0.0
## 0..1 strength of the red hurt vignette.
var hurt := 0.0
## The crate, when standing on it this step.
var standing_on: Node = null
## Seconds left before a knocked-down body may get up (it also waits to stop moving).
var knocked := 0.0
## True while the suit is a limp ragdoll.
var limp := false
## 0..1 how hard the air is rushing past in a fall (drives FOV, shake, streaks).
var rush := 0.0
## The body's spin in the air, rad/s (world axis * rate).
var omega := Vector3.ZERO
## In a fall (after a gravity shift, or dropping fast): WASD rolls and pitches the body.
var tumbling := false
var body: SuitBody

var tuning: Tuning
var _drag_k := 0.0
var _shake_t := 0.0
var _mouse := Vector2.ZERO
var _stride := 0.0
var _phase := 0.0
var _tuck := 0.0
var _getup_t := 1.0
var _getup_from := Transform3D.IDENTITY
## Seconds a jump press stays wanted; it fires on the first step the feet can push.
var _jump_buffer := 0.0
## Seconds since the feet last touched ground; INF once a jump or flip spends the grace.
var _since_ground := INF


## Configures the body from tuning. Call before adding to the tree.
func setup(t: Tuning) -> void:
	tuning = t
	_drag_k = GravityMath.drag_constant(t.num("air_density"), t.num("player_drag_area"))
	var shape := SphereShape3D.new()
	shape.radius = t.num("player_radius")
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	_set_solid(true)
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.12
	floor_stop_on_slope = true
	floor_block_on_wall = false
	safe_margin = 0.01


## Gives the player its body (already set up and in the tree).
func attach_body(b: SuitBody) -> void:
	body = b
	body.impact.connect(_on_limp_impact)


## Puts the player at [param pos] at rest, gravity back to the floor, facing [param yaw].
func spawn(pos: Vector3, yaw: float) -> void:
	if limp:
		_end_limp()
	gdir = Vector3.DOWN
	up_direction = Vector3.UP
	view.reset(yaw)
	knocked = 0.0
	rush = 0.0
	omega = Vector3.ZERO
	tumbling = false
	_getup_t = 1.0
	velocity = Vector3.ZERO
	global_position = pos
	reset_physics_interpolation()
	grounded = false
	dip = 0.0
	hurt = 0.0
	_stride = 0.0
	_mouse = Vector2.ZERO
	_jump_buffer = 0.0
	_since_ground = INF


## Gravity now pulls along [param down]. The body stays as it was: righting it is up to
## the player (and a weak reflex) on the way down.
func set_gravity(down: Vector3) -> void:
	var d := down.normalized()
	if d.dot(gdir) > 0.999:
		return
	gdir = d
	up_direction = -d
	grounded = false
	tumbling = true
	_since_ground = INF # no grace jump off ground that is no longer underfoot
	gravity_changed.emit(d)


## The way gravity's floor faces (not the body's up: see [method ViewFrame.up]).
func up() -> Vector3:
	return -gdir


## Where the eye is this physics step.
func eye_position() -> Vector3:
	return global_position + view.up() * tuning.num("eye_height")


## Where the eye is this rendered frame (between physics steps).
func eye_position_interpolated() -> Vector3:
	return get_global_transform_interpolated().origin + view.up() * (tuning.num("eye_height") - dip)


## Where the camera goes this frame: the eye (shaking in a fast fall), the limp head,
## or a blend from the head back to the eye while getting up.
func camera_transform() -> Transform3D:
	if limp:
		return body.head.get_global_transform_interpolated()
	var s := rush * rush * tuning.num("fall_shake")
	var shake := Quaternion.from_euler(Vector3(sin(_shake_t * 37.0) + sin(_shake_t * 23.0),
		sin(_shake_t * 29.0) + sin(_shake_t * 41.0), 0.0) * s)
	var eye := Transform3D(Basis(view.look() * shake), eye_position_interpolated())
	if _getup_t >= 1.0:
		return eye
	var e := _getup_t * _getup_t * (3.0 - 2.0 * _getup_t)
	return _getup_from.interpolate_with(eye, e)


## How far (radians) the body is from upright on the current ground.
func misalignment() -> float:
	return acos(clampf(view.up().dot(up()), -1.0, 1.0))


## Down: limp, or still waiting out a knockdown. Nothing moves or shoots.
func is_down() -> bool:
	return limp or knocked > 0.0


## Speed in m/s.
func speed() -> float:
	return velocity.length()


## Asks for a jump: it happens as soon as the feet can push, within
## [code]jump_buffer[/code] seconds, or [code]coyote_time[/code] after leaving a ledge.
func request_jump() -> void:
	_jump_buffer = tuning.num("jump_buffer")


func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse += (event as InputEventMouseMotion).screen_relative


func _process(delta: float) -> void:
	if active and not limp:
		var turn := tuning.num("key_turn") * delta
		var sens := tuning.num("look_sens")
		var keys := Vector2(Input.get_axis("look_right", "look_left"), Input.get_axis("look_down", "look_up"))
		view.add_look(keys.x * turn - _mouse.x * sens, keys.y * turn - _mouse.y * sens)
	_mouse = Vector2.ZERO
	dip *= exp(-7.5 * delta)
	hurt *= exp(-3.5 * delta)
	_shake_t += delta
	_getup_t = minf(1.0, _getup_t + delta / GETUP_BLEND)
	if body and not limp:
		var walk := 0.0
		if grounded:
			var flat_speed := (velocity - gdir * velocity.dot(gdir)).length()
			walk = clampf(flat_speed / tuning.num("move_speed"), 0.0, 1.0)
			_phase += flat_speed * delta / tuning.num("step_length") * PI # a step each half cycle
		var tuck_to := 0.0
		if not grounded:
			tuck_to = 1.0 if tumbling and _steer_keys() != Vector2.ZERO else 0.25
		_tuck = lerpf(_tuck, tuck_to, GravityMath.blend(8.0, delta))
		var frame := Transform3D(Basis(view.flat()), get_global_transform_interpolated().origin)
		body.pose(frame, _phase, walk, _tuck, delta)


func _physics_process(delta: float) -> void:
	if limp:
		_limp_step(delta)
		return
	var g := tuning.num("gravity")
	knocked = maxf(0.0, knocked - delta)
	var keys := _steer_keys() if active and knocked <= 0.0 else Vector2.ZERO
	if grounded:
		tumbling = false
	elif velocity.dot(gdir) > tuning.num("air_tumble_speed"):
		tumbling = true # falling, not just jumping: the keys roll you now

	var wish := Vector3.ZERO
	var flat := view.flat()
	if tumbling and not grounded:
		# W rolls forward (about -right), S back; A rolls left (about +back), D right.
		var steer := (flat * Vector3.RIGHT) * -keys.y + (flat * Vector3.BACK) * -keys.x
		_spin(steer.limit_length(1.0), delta)
	else:
		wish = flat * Vector3.FORWARD * keys.y + flat * Vector3.RIGHT * keys.x
		wish -= gdir * wish.dot(gdir) # walk along the ground even while the body settles
		if not grounded:
			_spin(Vector3.ZERO, delta)
	var moving := wish.length_squared() > 0.0001
	if moving:
		wish = wish.normalized()
	if grounded:
		omega = Vector3.ZERO
		_settle(delta)

	var v := velocity
	var fall := v.dot(gdir)
	var side := v - gdir * fall
	var rate := tuning.num("ground_accel") if grounded else (tuning.num("air_control") if moving else 0.0)
	side = side.lerp(wish * tuning.num("move_speed"), GravityMath.blend(rate, delta))
	fall += g * delta
	var feet_down := grounded or _since_ground <= tuning.num("coyote_time")
	if active and knocked <= 0.0 and feet_down and _jump_buffer > 0.0:
		fall = -GravityMath.jump_speed(g, tuning.num("jump_height"))
		jumped.emit()
		_jump_buffer = 0.0
		_since_ground = INF
	_jump_buffer -= delta
	v = side + gdir * fall
	v += GravityMath.drag_acceleration(v, _drag_k, tuning.num("player_mass")) * delta
	velocity = v
	var arriving := v.dot(gdir)

	up_direction = -gdir
	move_and_slide()
	_touch_bodies(v, g)

	var was_grounded := grounded
	grounded = is_on_floor()
	_since_ground = 0.0 if grounded else _since_ground + delta
	_update_rush()
	# Walls and ceilings hurt too: flipping gravity just before the ground does not
	# cancel a deadly fall, it turns the old ground into a wall you hit at full speed.
	var hit := wall_impact(v)
	# Grounded motion keeps speed into walls that are not floor-ward of up (a ceiling
	# after a sideways flip); a hit should stop it, not press on and hit again each step.
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if velocity.dot(n) < 0.0:
			velocity -= n * velocity.dot(n)
	if hit < tuning.num("wall_impact_min"):
		hit = 0.0
	if grounded and not was_grounded:
		_land(maxf(arriving, hit))
	elif hit > 0.0:
		_land(hit)
	if grounded and active and not limp:
		_stride += (v - gdir * v.dot(gdir)).length() * delta
		if _stride >= tuning.num("step_length"):
			_stride = 0.0
			footstep.emit(standing_on != null)


## Fastest speed (m/s) this step's move drove into a surface that is not the floor,
## given the velocity [param v] the move started with.
func wall_impact(v: Vector3) -> float:
	var worst := 0.0
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_angle(0, up_direction) <= floor_max_angle:
			continue
		worst = maxf(worst, -v.dot(c.get_normal()))
	return worst


## WASD as (right, forward), each -1..1.
func _steer_keys() -> Vector2:
	return Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward"))


## Turns the body through the air: [param steer] rolls it, the reflex rights it.
func _spin(steer: Vector3, delta: float) -> void:
	omega = GravityMath.air_spin(omega, view.up(), up(), steer, tuning.num("air_roll_accel"),
		tuning.num("air_assist"), tuning.num("air_assist_damp"), delta)
	var rate := omega.length()
	if rate > 0.0001:
		view.rotate_body(Quaternion(omega / rate, rate * delta))


## On the ground the body straightens up quickly (a small lean is only balance).
func _settle(delta: float) -> void:
	if misalignment() < 0.001:
		return
	var arc := Quaternion(view.up(), up())
	view.rotate_body(Quaternion.IDENTITY.slerp(arc, GravityMath.blend(12.0, delta)))


func _update_rush() -> void:
	var start := tuning.num("rush_start")
	rush = 0.0 if grounded else clampf((speed() - start) / (tuning.num("lethal_speed") - start), 0.0, 1.0)


## Pushes the crate with the player's momentum, or loads it with the player's weight.
## Each body is pushed and loaded at most once per step, however many contacts it has.
func _touch_bodies(v: Vector3, g: float) -> void:
	standing_on = null
	var pushes := {} # RigidBody3D -> [gap, into, offset], the hardest contact
	var loads := {} # RigidBody3D -> offset
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var rb := c.get_collider() as RigidBody3D
		if rb == null:
			continue
		var n := c.get_normal()
		var offset := c.get_position() - rb.global_position
		if n.dot(up()) > 0.7:
			standing_on = rb
			loads[rb] = offset
			continue
		var into := -n
		var gap := v.dot(into) - rb.linear_velocity.dot(into)
		if gap > 0.0 and (not pushes.has(rb) or gap > pushes[rb][0]):
			pushes[rb] = [gap, into, offset]
	for rb: RigidBody3D in loads:
		rb.apply_force(gdir * tuning.num("player_mass") * g, loads[rb])
	for rb: RigidBody3D in pushes:
		var gap: float = pushes[rb][0]
		var into: Vector3 = pushes[rb][1]
		var share := tuning.num("push_share")
		rb.apply_impulse(into * gap * rb.mass * share, pushes[rb][2])
		# The slide stopped the player dead against the crate. In a shove both move on
		# together, so the player keeps the crate's new speed along the push.
		var together := rb.linear_velocity.dot(into) + gap * share
		var mine := velocity.dot(into)
		if together > mine:
			velocity += into * (together - mine)


func _land(speed_in: float) -> void:
	var lethal := tuning.num("lethal_speed")
	if GravityMath.is_lethal(speed_in, lethal):
		active = false
		hurt = 1.0
		died.emit(speed_in)
		return
	var r := GravityMath.landing_severity(speed_in, lethal)
	# Even a soft touchdown floors you if the body was not upright.
	var down := GravityMath.knockdown_time(misalignment(), r, deg_to_rad(tuning.num("knockdown_angle")),
		tuning.num("knockdown_impact"), tuning.num("knockdown_min"), tuning.num("knockdown_max"))
	if down > 0.0 and not limp and body:
		knocked = down
		_go_limp()
		knocked_down.emit(down)
	if speed_in < QUIET_LANDING:
		return
	dip = maxf(dip, r * tuning.num("land_dip"))
	if r > tuning.num("hurt_ratio"):
		hurt = maxf(hurt, r)
	landed.emit(speed_in, r)


func _go_limp() -> void:
	limp = true
	_set_solid(false)
	body.go_limp(velocity, omega, global_position)


## Limp: the player follows the torso (rooms, plate and bounds see it there) until the
## knockdown time is up and the body has stopped, then stands up where it lies.
func _limp_step(delta: float) -> void:
	knocked = maxf(0.0, knocked - delta)
	global_position = body.torso.global_position
	velocity = body.torso.linear_velocity
	grounded = false
	_update_rush()
	if knocked <= 0.0 and body.settled():
		_get_up()


func _get_up() -> void:
	var head := body.head.global_transform
	_getup_from = body.head.get_global_transform_interpolated()
	_getup_t = 0.0
	# Face the way the head lay, then turn upright on the ground: the look stays put.
	view.base = head.basis.get_rotation_quaternion()
	view.yaw = 0.0
	view.pitch = 0.0
	view.rebase(up())
	_end_limp()
	global_position = body.torso.global_position + up() * 0.45
	# Lying against a wall, the standing sphere starts a little inside it: step out.
	for i in 8:
		move_and_collide(Vector3.ZERO)
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	omega = Vector3.ZERO
	tumbling = false


func _end_limp() -> void:
	limp = false
	knocked = 0.0
	body.end_limp()
	_set_solid(true)


func _set_solid(on: bool) -> void:
	collision_layer = PhysicsLayers.PLAYER if on else 0
	collision_mask = (PhysicsLayers.WORLD | PhysicsLayers.CUBE) if on else 0


## The limp body slammed into something: as hard as a deadly landing, it kills.
func _on_limp_impact(speed_lost: float) -> void:
	var lethal := tuning.num("lethal_speed")
	if GravityMath.is_lethal(speed_lost, lethal):
		active = false
		hurt = 1.0
		died.emit(speed_lost)
	elif speed_lost >= QUIET_LANDING:
		landed.emit(speed_lost, GravityMath.landing_severity(speed_lost, lethal))
