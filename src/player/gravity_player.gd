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

## Landings slower than this make no sound, m/s.
const QUIET_LANDING := 2.5

## Which way things fall (unit vector).
var gdir := Vector3.DOWN
var view := ViewFrame.new()
## Whether input moves the player.
var active := false
var grounded := false
## The smoothed camera orientation (rolls to new ground over flip_time).
var cam_q := Quaternion.IDENTITY
## How far the view currently dips from a landing, m.
var dip := 0.0
## 0..1 strength of the red hurt vignette.
var hurt := 0.0
## The crate, when standing on it this step.
var standing_on: Node = null

var tuning: Tuning
var _drag_k := 0.0
var _flip_from := Quaternion.IDENTITY
var _flip_t := 99.0
var _mouse := Vector2.ZERO
var _stride := 0.0
var _jump_queued := false


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
	velocity = Vector3.ZERO
	global_position = pos
	reset_physics_interpolation()
	grounded = false
	dip = 0.0
	hurt = 0.0
	_stride = 0.0
	_mouse = Vector2.ZERO
	_jump_queued = false


## Gravity now pulls along [param down]. The view rolls; the look stays where it was.
func set_gravity(down: Vector3) -> void:
	var d := down.normalized()
	if d.dot(gdir) > 0.999:
		return
	view.rebase(-d)
	_flip_from = cam_q
	_flip_t = 0.0
	gdir = d
	up_direction = -d
	grounded = false
	gravity_changed.emit(d)


## The player's up.
func up() -> Vector3:
	return -gdir


## Where the eye is this physics step.
func eye_position() -> Vector3:
	return global_position + up() * tuning.num("eye_height")


## Where the eye is this rendered frame (between physics steps).
func eye_position_interpolated() -> Vector3:
	return get_global_transform_interpolated().origin + up() * (tuning.num("eye_height") - dip)


## Speed in m/s.
func speed() -> float:
	return velocity.length()


## Queues a jump for the next physics step.
func request_jump() -> void:
	_jump_queued = true


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
	var e := clampf(_flip_t / maxf(tuning.num("flip_time"), 0.001), 0.0, 1.0)
	cam_q = _flip_from.slerp(view.look(), e * e * (3.0 - 2.0 * e))
	dip *= exp(-7.5 * delta)
	hurt *= exp(-3.5 * delta)


func _physics_process(delta: float) -> void:
	var g := tuning.num("gravity")
	var wish := Vector3.ZERO
	if active:
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
	if active and grounded and _jump_queued:
		fall = -GravityMath.jump_speed(g, tuning.num("jump_height"))
		jumped.emit()
	_jump_queued = false
	v = side + gdir * fall
	v += GravityMath.drag_acceleration(v, _drag_k, tuning.num("player_mass")) * delta
	velocity = v
	var arriving := v.dot(gdir)

	up_direction = -gdir
	move_and_slide()
	_touch_bodies(v, g)

	var was_grounded := grounded
	grounded = is_on_floor()
	if grounded and not was_grounded:
		_land(arriving)
	if grounded and active:
		_stride += (v - gdir * v.dot(gdir)).length() * delta
		if _stride >= tuning.num("step_length"):
			_stride = 0.0
			footstep.emit(standing_on != null)


## Pushes the crate with the player's momentum, or loads it with the player's weight.
func _touch_bodies(v: Vector3, g: float) -> void:
	standing_on = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody3D
		if body == null:
			continue
		var n := c.get_normal()
		var offset := c.get_position() - body.global_position
		if n.dot(up()) > 0.7:
			standing_on = body
			body.apply_force(gdir * tuning.num("player_mass") * g, offset)
			continue
		var into := -n
		var gap := v.dot(into) - body.linear_velocity.dot(into)
		if gap > 0.0:
			body.apply_impulse(into * gap * body.mass * tuning.num("push_share"), offset)


func _land(speed_in: float) -> void:
	if speed_in < QUIET_LANDING:
		return
	var lethal := tuning.num("lethal_speed")
	if GravityMath.is_lethal(speed_in, lethal):
		active = false
		hurt = 1.0
		died.emit(speed_in)
		return
	var r := GravityMath.landing_severity(speed_in, lethal)
	dip = maxf(dip, r * tuning.num("land_dip"))
	if r > tuning.num("hurt_ratio"):
		hurt = maxf(hurt, r)
	landed.emit(speed_in, r)
