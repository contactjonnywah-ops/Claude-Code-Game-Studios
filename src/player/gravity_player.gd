class_name GravityPlayer
extends CharacterBody3D
## The player: a sphere that walks on whatever surface gravity points at.
##
## Motion is integrated by hand each physics step: gravity along [member gdir],
## quadratic air drag, feet that grip on the ground and momentum that carries in
## the air. Landings are judged by the speed they arrive with: hard ones hurt,
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
## Landed off balance or too hard: down for [param seconds], no moving or shooting.
signal knocked_down(seconds: float)

## Landings slower than this make no sound, m/s.
const QUIET_LANDING := 2.5

## Which way things fall (unit vector).
var gdir := Vector3.DOWN
var view := ViewFrame.new()
## Whether input moves the player.
var active := false
var grounded := false
## The body's orientation: turns to new ground at reorient_rate (the camera follows it).
var cam_q := Quaternion.IDENTITY
## How far the view currently dips from a landing, m.
var dip := 0.0
## 0..1 strength of the red hurt vignette.
var hurt := 0.0
## The crate, when standing on it this step.
var standing_on: Node = null
## Seconds left on the floor after a knockdown; nothing moves or shoots while above 0.
var knocked := 0.0
## 0..1 how hard the air is rushing past in a fall (drives FOV, shake, streaks).
var rush := 0.0

var tuning: Tuning
var _drag_k := 0.0
var _flip_from := Quaternion.IDENTITY
var _flip_t := 99.0
var _flip_dur := 1.0
var _flip_angle := 0.0
var _knock_len := 1.0
# The body rig: springs for roll, pitch (rad) and slump (m) that tip the view over.
var _rig := Vector3.ZERO
var _rig_v := Vector3.ZERO
var _rig_side := 1.0
var _shake_t := 0.0
var _mouse := Vector2.ZERO
var _stride := 0.0
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
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.CUBE
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.12
	floor_stop_on_slope = true
	floor_block_on_wall = false
	safe_margin = 0.01


## Puts the player at [param pos] at rest, gravity back to the floor, facing [param yaw].
func spawn(pos: Vector3, yaw: float) -> void:
	gdir = Vector3.DOWN
	up_direction = Vector3.UP
	view.reset(yaw)
	cam_q = view.look()
	_flip_t = 99.0
	_flip_angle = 0.0
	knocked = 0.0
	rush = 0.0
	_rig = Vector3.ZERO
	_rig_v = Vector3.ZERO
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


## Gravity now pulls along [param down]. The view rolls; the look stays where it was.
func set_gravity(down: Vector3) -> void:
	var d := down.normalized()
	if d.dot(gdir) > 0.999:
		return
	# The body twists to the new ground at a fixed rate: a half turn takes twice a quarter.
	_flip_angle = acos(clampf(d.dot(gdir), -1.0, 1.0))
	_flip_dur = maxf(0.05, _flip_angle / deg_to_rad(tuning.num("reorient_rate")))
	view.rebase(-d)
	_flip_from = cam_q
	_flip_t = 0.0
	_rig_side = -_rig_side
	_rig_v += Vector3(0.8 * _rig_side, 2.5, 0.0) # the stomach-drop jolt of the shift
	gdir = d
	up_direction = -d
	grounded = false
	_since_ground = INF # no grace jump off ground that is no longer underfoot
	gravity_changed.emit(d)


## The player's up.
func up() -> Vector3:
	return -gdir


## Where the eye is this physics step.
func eye_position() -> Vector3:
	return global_position + up() * tuning.num("eye_height")


## Where the eye is this rendered frame (between physics steps).
func eye_position_interpolated() -> Vector3:
	return get_global_transform_interpolated().origin + up() * (tuning.num("eye_height") - dip - _rig.z)


## The body rig's tilt plus the shake of a fast fall, applied on top of [member cam_q].
func body_offset() -> Quaternion:
	var s := rush * rush * tuning.num("fall_shake")
	var shake := Vector3(sin(_shake_t * 37.0) + sin(_shake_t * 23.0), sin(_shake_t * 29.0) + sin(_shake_t * 41.0), 0.0) * s
	return Quaternion.from_euler(Vector3(_rig.y + shake.x, shake.y, _rig.x))


## How far (radians) the body still is from upright on the current ground.
func misalignment() -> float:
	var e := clampf(_flip_t / _flip_dur, 0.0, 1.0)
	return _flip_angle * (1.0 - e * e * (3.0 - 2.0 * e))


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
	if active:
		var turn := tuning.num("key_turn") * delta
		var sens := tuning.num("look_sens")
		var keys := Vector2(Input.get_axis("look_right", "look_left"), Input.get_axis("look_down", "look_up"))
		view.add_look(keys.x * turn - _mouse.x * sens, keys.y * turn - _mouse.y * sens)
	_mouse = Vector2.ZERO
	_flip_t += delta
	var e := clampf(_flip_t / _flip_dur, 0.0, 1.0)
	cam_q = _flip_from.slerp(view.look(), e * e * (3.0 - 2.0 * e))
	dip *= exp(-7.5 * delta)
	hurt *= exp(-3.5 * delta)
	_shake_t += delta
	# Knocked down: the body tips over sideways and slumps to the floor, then gets up
	# for the last third. Damped springs give the fall and the rise their overshoot.
	var target := Vector3.ZERO
	if knocked > 0.0 and knocked > _knock_len * 0.35:
		target = Vector3(1.25 * _rig_side, -0.35, tuning.num("eye_height") + 0.35)
	_rig_v += ((target - _rig) * 60.0 - _rig_v * 11.0) * delta
	_rig += _rig_v * delta


func _physics_process(delta: float) -> void:
	var g := tuning.num("gravity")
	var wish := Vector3.ZERO
	knocked = maxf(0.0, knocked - delta)
	var upright := knocked <= 0.0
	if active and upright:
		var flat := view.flat()
		wish = flat * Vector3.FORWARD * Input.get_axis("move_back", "move_forward") \
			+ flat * Vector3.RIGHT * Input.get_axis("move_left", "move_right")
	var moving := wish.length_squared() > 0.0
	if moving:
		wish = wish.normalized()

	var v := velocity
	var fall := v.dot(gdir)
	var side := v - gdir * fall
	var rate := tuning.num("ground_accel") if grounded else (tuning.num("air_control") if moving else 0.0)
	side = side.lerp(wish * tuning.num("move_speed"), GravityMath.blend(rate, delta))
	fall += g * delta
	var feet_down := grounded or _since_ground <= tuning.num("coyote_time")
	if active and upright and feet_down and _jump_buffer > 0.0:
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
	var start := tuning.num("rush_start")
	rush = 0.0 if grounded else clampf((speed() - start) / (tuning.num("lethal_speed") - start), 0.0, 1.0)
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
	if grounded and active:
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


## Pushes the crate with the player's momentum, or loads it with the player's weight.
## Each body is pushed and loaded at most once per step, however many contacts it has.
func _touch_bodies(v: Vector3, g: float) -> void:
	standing_on = null
	var pushes := {} # RigidBody3D -> [gap, into, offset], the hardest contact
	var loads := {} # RigidBody3D -> offset
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody3D
		if body == null:
			continue
		var n := c.get_normal()
		var offset := c.get_position() - body.global_position
		if n.dot(up()) > 0.7:
			standing_on = body
			loads[body] = offset
			continue
		var into := -n
		var gap := v.dot(into) - body.linear_velocity.dot(into)
		if gap > 0.0 and (not pushes.has(body) or gap > pushes[body][0]):
			pushes[body] = [gap, into, offset]
	for body: RigidBody3D in loads:
		body.apply_force(gdir * tuning.num("player_mass") * g, loads[body])
	for body: RigidBody3D in pushes:
		var gap: float = pushes[body][0]
		var into: Vector3 = pushes[body][1]
		var share := tuning.num("push_share")
		body.apply_impulse(into * gap * body.mass * share, pushes[body][2])
		# The slide stopped the player dead against the crate. In a shove both move on
		# together, so the player keeps the crate's new speed along the push.
		var together := body.linear_velocity.dot(into) + gap * share
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
	# Even a soft touchdown floors you if the body had not turned upright yet.
	var down := GravityMath.knockdown_time(misalignment(), r, deg_to_rad(tuning.num("knockdown_angle")),
		tuning.num("hurt_ratio"), tuning.num("knockdown_min"), tuning.num("knockdown_max"))
	if down > 0.0 and knocked <= 0.0:
		knocked = down
		_knock_len = down
		knocked_down.emit(down)
	if speed_in < QUIET_LANDING:
		return
	dip = maxf(dip, r * tuning.num("land_dip"))
	if r > tuning.num("hurt_ratio"):
		hurt = maxf(hurt, r)
	landed.emit(speed_in, r)
