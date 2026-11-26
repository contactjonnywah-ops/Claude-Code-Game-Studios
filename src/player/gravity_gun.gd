class_name GravityGun
extends Node3D
## The gun held in view, and what it does.
##
## GRAVITY: a shot at a dark panel makes that panel the ground: world gravity turns to
## point into it, for the player and the crate alike.
## TRACTION: holding the trigger on the crate locks it in stasis over
## [code]traction_lock_time[/code], then carries it weightless in front of the eye.

enum Mode { GRAVITY, TRACTION }

## A gravity shot landed; [param grip] when it hit a dark panel.
signal shot(grip: bool, where: Vector3)
signal mode_changed(mode: Mode)
signal locked
## The crate was let go (it keeps its momentum).
signal released

var mode := Mode.GRAVITY
## 0..1 how far the lock has set in.
var lock := 0.0
var holding := false
## What the crosshair is on: { "kind": "none"|"same"|"fall"|"cube", "fall": m, "impact": m/s, "lethal": bool }.
var aim: Dictionary = { "kind": "none" }
## True while the beam is drawn.
var beam_on := false

var _player: GravityPlayer
var _cube: GravityCube
var _tuning: Tuning
var _mats: SurfaceMaterials
var _snag := 0.0
var _beam_end := Vector3.ZERO
var _beam_flash := 0.0
var _recoil := 0.0
var _bob := 0.0
var _query := PhysicsRayQueryParameters3D.new()
var _fall_query := PhysicsShapeQueryParameters3D.new()
var _fall_shape := SphereShape3D.new()
var _muzzle: Node3D
var _beam: MeshInstance3D
var _marker: MeshInstance3D
var _stasis: MeshInstance3D
var _beam_mat: StandardMaterial3D

const REST := Vector3(0.26, -0.22, -0.5)


## Wires the gun to the player and crate, and builds its viewmodel and effects under [param world].
func setup(player: GravityPlayer, cube: GravityCube, tuning: Tuning, mats: SurfaceMaterials, world: Node3D) -> void:
	_player = player
	_cube = cube
	_tuning = tuning
	_mats = mats
	_query.hit_back_faces = false
	_build_viewmodel()
	_beam_mat = SurfaceMaterials._glow(SurfaceMaterials.GRAVITY_COLOR, 2.0)
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam = _effect(CylinderMesh.new(), _beam_mat, world)
	(_beam.mesh as CylinderMesh).top_radius = 0.018
	(_beam.mesh as CylinderMesh).bottom_radius = 0.018
	(_beam.mesh as CylinderMesh).height = 1.0
	var ring := TorusMesh.new()
	ring.inner_radius = 0.45
	ring.outer_radius = 0.6
	var ring_mat := SurfaceMaterials._glow(SurfaceMaterials.GRAVITY_COLOR, 1.2)
	_marker = _effect(ring, ring_mat, world)
	var ball := SphereMesh.new()
	ball.radius = 0.95
	ball.height = 1.9
	var ball_mat := SurfaceMaterials._glow(SurfaceMaterials.TRACTION_COLOR, 1.5)
	ball_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball_mat.albedo_color.a = 0.28
	ball_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_stasis = _effect(ball, ball_mat, world)


## Back to the start: gravity mode, nothing held, no marker.
func reset() -> void:
	mode = Mode.GRAVITY
	_let_go(false)
	_marker.visible = false
	_beam_flash = 0.0
	_apply_mode_color()


## One physics step of the gun. [param fire_pressed] is the trigger going down this
## step, [param fire_held] the trigger held, [param switch_pressed] the mode key.
func physics_update(delta: float, fire_pressed: bool, fire_held: bool, switch_pressed: bool) -> void:
	var eye := _player.eye_position()
	var dir := _player.view.forward()
	if switch_pressed:
		mode = Mode.TRACTION if mode == Mode.GRAVITY else Mode.GRAVITY
		_let_go(true)
		_apply_mode_color()
		mode_changed.emit(mode)
	beam_on = false
	if mode == Mode.GRAVITY:
		if fire_pressed:
			_shoot(eye, dir)
	elif fire_held:
		_traction(delta, eye, dir)
	else:
		_let_go(true)
	_beam_flash -= delta
	if _beam_flash > 0.0:
		beam_on = true
	_update_aim()


func _shoot(eye: Vector3, dir: Vector3) -> void:
	var hit := _ray(eye, dir, _tuning.num("gun_range"), PhysicsLayers.SHOT_MASK)
	_recoil = 1.0
	if hit.is_empty():
		_beam_end = eye + dir * _tuning.num("gun_range")
		_beam_flash = 0.12
		shot.emit(false, _beam_end)
		return
	var p: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	_beam_end = p
	_beam_flash = 0.12
	var grip: bool = (hit["collider"] as Node).is_in_group(LevelBuilder.GRIP_GROUP)
	shot.emit(grip, p)
	if not grip:
		return
	_marker.visible = true
	_marker.global_transform = Transform3D(_basis_along(n, 1.0).scaled_local(Vector3(1, 0.25, 1)), p + n * 0.03)
	_player.set_gravity(-n)


func _traction(delta: float, eye: Vector3, dir: Vector3) -> void:
	beam_on = true
	if not holding:
		var reach := _tuning.num("traction_range")
		var hit := _ray(eye, dir, reach, PhysicsLayers.SOLID_MASK)
		var on: bool = not hit.is_empty() and hit["collider"] == _cube
		_beam_end = hit["position"] if not hit.is_empty() else eye + dir * reach
		if not on:
			lock = 0.0
			return
		lock = minf(1.0, lock + delta / _tuning.num("traction_lock_time"))
		var calm := exp(-20.0 * lock * delta) # stasis sets in
		_cube.linear_velocity *= calm
		_cube.angular_velocity *= calm
		if lock >= 1.0:
			holding = true
			_cube.held = true
			locked.emit()
		return
	var cube_pos := _cube.global_position
	var rel := eye + dir * _tuning.num("traction_hold") - cube_pos
	var off := cube_pos - _player.global_position
	var along := off.dot(_player.gdir)
	var side := (off - _player.gdir * along).length()
	# A crate snagged behind something for a moment, or one under your own feet, breaks the lock.
	_snag = _snag + delta if rel.length() > _tuning.num("traction_break") else 0.0
	if _snag > _tuning.num("traction_snag_time") or (along > 0.3 and side < 0.9) or _player.standing_on == _cube:
		_let_go(true)
		return
	_cube.linear_velocity = (rel * _tuning.num("traction_pull")).limit_length(_tuning.num("traction_max_speed"))
	_cube.angular_velocity *= exp(-10.0 * delta)
	_beam_end = cube_pos


func _let_go(emit: bool) -> void:
	if holding and emit:
		released.emit()
	holding = false
	lock = 0.0
	_snag = 0.0
	if _cube:
		_cube.held = false


func _update_aim() -> void:
	var eye := _player.eye_position()
	var dir := _player.view.forward()
	aim = { "kind": "none" }
	if mode == Mode.TRACTION:
		var t := _ray(eye, dir, _tuning.num("traction_range"), PhysicsLayers.SOLID_MASK)
		if holding or (not t.is_empty() and t["collider"] == _cube):
			aim = { "kind": "cube" }
		return
	var hit := _ray(eye, dir, _tuning.num("gun_range"), PhysicsLayers.SHOT_MASK)
	if hit.is_empty() or not (hit["collider"] as Node).is_in_group(LevelBuilder.GRIP_GROUP):
		return
	var nd: Vector3 = -(hit["normal"] as Vector3)
	if nd.dot(_player.gdir) > 0.999:
		aim = { "kind": "same" }
		return
	# How far the real fall would be, and how fast you would land with air drag.
	var dist := fall_distance(nd)
	var k := GravityMath.drag_constant(_tuning.num("air_density"), _tuning.num("player_drag_area"))
	var v0 := maxf(0.0, _player.velocity.dot(nd))
	var impact := GravityMath.impact_speed(dist, _tuning.num("gravity"), _tuning.num("player_mass"), k, v0)
	aim = { "kind": "fall", "fall": dist, "impact": impact, "lethal": GravityMath.is_lethal(impact, _tuning.num("lethal_speed")) }


## How far (m) the player would fall along [param down] before touching anything solid.
## Sweeps the player's whole sphere, not a line from its centre, so a ledge the body
## would clip counts; the player still drifts sideways with its velocity, which this ignores.
func fall_distance(down: Vector3) -> float:
	var reach := _tuning.num("gun_range")
	# A hair under the real radius, so the floor the player stands on now is not a hit.
	_fall_shape.radius = maxf(0.01, _tuning.num("player_radius") - 0.02)
	_fall_query.shape = _fall_shape
	_fall_query.transform = Transform3D(Basis.IDENTITY, _player.global_position)
	_fall_query.motion = down.normalized() * reach
	_fall_query.collision_mask = PhysicsLayers.SOLID_MASK
	var safe := _player.get_world_3d().direct_space_state.cast_motion(_fall_query)
	return reach * safe[0] if safe.size() > 0 else reach


func _ray(from: Vector3, dir: Vector3, length: float, mask: int) -> Dictionary:
	_query.from = from
	_query.to = from + dir * length
	_query.collision_mask = mask
	return _player.get_world_3d().direct_space_state.intersect_ray(_query)


func _process(delta: float) -> void:
	# The viewmodel: a little bob while walking, a kick on each shot.
	var walk := 0.0
	if _player.grounded:
		walk = (_player.velocity - _player.gdir * _player.velocity.dot(_player.gdir)).length()
	_bob += delta * walk * 1.9
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	var amp := minf(walk / 5.0, 1.0) * 0.012
	position = REST + Vector3(cos(_bob) * amp, -absf(sin(_bob)) * amp, _recoil * 0.06)
	rotation.x = _recoil * 0.12
	# Effects, drawn where the interpolated bodies are this frame.
	var tip := _muzzle.global_position
	var end := _cube.get_global_transform_interpolated().origin if holding else _beam_end
	_beam.visible = beam_on and tip.distance_to(end) > 0.05
	if _beam.visible:
		var d := end - tip
		_beam.global_transform = Transform3D(_basis_along(d.normalized(), d.length()), tip + d * 0.5)
	_stasis.visible = lock > 0.0
	if _stasis.visible:
		_stasis.global_position = _cube.get_global_transform_interpolated().origin
		_stasis.scale = Vector3.ONE * maxf(0.01, lock) * (1.0 + 0.03 * sin(Time.get_ticks_msec() * 0.012))


## A basis whose Y axis runs along [param axis] with length [param length].
static func _basis_along(axis: Vector3, length: float) -> Basis:
	var y := axis.normalized()
	var helper := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := helper.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y * length, z)


func _apply_mode_color() -> void:
	var c := SurfaceMaterials.GRAVITY_COLOR if mode == Mode.GRAVITY else SurfaceMaterials.TRACTION_COLOR
	_mats.gun_glow.albedo_color = c
	_mats.gun_glow.emission = c
	_beam_mat.albedo_color = c
	_beam_mat.emission = c


func _effect(mesh: Mesh, mat: Material, world: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	world.add_child(mi)
	return mi


func _build_viewmodel() -> void:
	position = REST
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_part(_box(0.09, 0.1, 0.34), _mats.gun_body, Vector3(0, 0, 0))
	_part(_box(0.06, 0.16, 0.07), _mats.gun_body, Vector3(0, -0.11, 0.11)).rotation.x = 0.25
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.035
	barrel.bottom_radius = 0.05
	barrel.height = 0.22
	_part(barrel, _mats.gun_body, Vector3(0, 0.01, -0.26)).rotation.x = PI / 2.0
	for z: float in [-0.3, -0.2]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.046
		ring.outer_radius = 0.074
		_part(ring, _mats.gun_glow, Vector3(0, 0.01, z)).rotation.x = PI / 2.0
	var lamp := SphereMesh.new()
	lamp.radius = 0.035
	lamp.height = 0.07
	_part(lamp, _mats.gun_glow, Vector3(0, 0.07, 0.02))
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, 0.01, -0.38)
	add_child(_muzzle)


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _part(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
