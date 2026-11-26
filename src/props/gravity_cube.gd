class_name GravityCube
extends RigidBody3D
## The crate: a real rigid body that tumbles, slides and falls whichever way gravity points.
##
## World gravity comes from the physics space (the gun changes it). Air drag is
## quadratic. While the traction beam holds it, the crate is weightless and the beam
## sets its velocity. Emits [signal impacted] on every hard contact for the sound.

## A hard contact: [param speed] is the speed lost in m/s, at [param where].
signal impacted(speed: float, where: Vector3)

## Speed lost in one step that counts as an impact, m/s.
const IMPACT_THRESHOLD := 1.2

## Sliding speed along a surface while touching it, m/s (drives the scrape loop).
var slide_speed := 0.0
## True while the traction beam holds the crate in stasis.
var held := false:
	set(v):
		held = v
		gravity_scale = 0.0 if v else 1.0

var _drag_k := 0.0
var _prev_velocity := Vector3.ZERO
var _reset_to: Variant = null
var _cooldown := 0.0


## Configures mass, contact behaviour and drag. Call before adding to the tree.
func setup(tuning: Tuning) -> void:
	var size := tuning.num("cube_size")
	mass = tuning.num("cube_mass")
	_drag_k = GravityMath.drag_constant(tuning.num("air_density"), tuning.num("cube_drag_area"))
	var pm := PhysicsMaterial.new()
	pm.friction = tuning.num("friction")
	pm.bounce = tuning.num("bounce")
	physics_material_override = pm
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	angular_damp = 0.05
	linear_damp = 0.0
	collision_layer = PhysicsLayers.CUBE
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.CUBE | PhysicsLayers.PLAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)


## Teleports the crate to [param pos] at rest on the next physics step.
func reset_to(pos: Vector3) -> void:
	held = false
	_reset_to = pos


func _physics_process(_delta: float) -> void:
	if not held:
		apply_central_force(GravityMath.drag_acceleration(linear_velocity, _drag_k, mass) * mass)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_to != null:
		state.transform = Transform3D(Basis.IDENTITY, _reset_to)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_prev_velocity = Vector3.ZERO
		_reset_to = null
		return
	var v := state.linear_velocity
	var touching := state.get_contact_count() > 0
	_cooldown -= state.step
	if touching:
		var lost := (_prev_velocity - v).length()
		if lost > IMPACT_THRESHOLD and _cooldown <= 0.0:
			_cooldown = 0.06
			impacted.emit(lost, state.transform.origin)
		var n := state.get_contact_local_normal(0)
		slide_speed = (v - n * v.dot(n)).length()
	else:
		slide_speed = 0.0
	_prev_velocity = v
