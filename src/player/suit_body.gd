class_name SuitBody
extends Node3D
## The player's body: torso, head and two legs of thigh and shin, built from capsules.
##
## Standing or falling, the parts are posed by hand each frame: legs swing with the
## stride, tuck while you roll in the air, dangle otherwise; they touch nothing. Knocked
## down, the same parts become a ragdoll: rigid bodies joined at the neck, hips and knees
## that carry the player's momentum and spin until they settle.
##
## Usage:
## [codeblock]
## var body := SuitBody.new()
## world.add_child(body)
## body.setup(tuning.num("player_mass"), mats.suit, mats.suit_dark)
## body.pose(frame, stride_phase, walk, tuck, delta)   # each frame while upright
## body.go_limp(velocity, omega, player.global_position)
## if body.settled(): player.global_position = body.torso.global_position
## body.end_limp()
## [/codeblock]

## The limp torso hit something and lost [param speed] m/s in one step.
signal impact(speed: float)

## Hip height below the player's centre, m (the centre is a body radius above the floor).
const HIP := Vector3(0.1, -0.05, 0.1)
const THIGH := 0.3
const SHIN := 0.25
## Speed lost in one step that counts as the limp body hitting something, m/s.
const IMPACT_MIN := 3.0

var torso: RigidBody3D
var head: RigidBody3D
var limp := false

var _thighs: Array[RigidBody3D] = []
var _shins: Array[RigidBody3D] = []
## Current leg angles [left thigh, right thigh, left knee, right knee], radians.
var _angles := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _prev_v := Vector3.ZERO


## Builds the parts at rest and joins them. [param mass] is split like a person's.
func setup(mass: float, suit: Material, boots: Material) -> void:
	torso = _part("Torso", _capsule(0.17, 0.5), suit, mass * 0.5)
	head = _part("Head", _sphere(0.12), suit, mass * 0.075)
	head.get_child(0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY # the eye is in it
	for i in 2:
		_thighs.append(_part("Thigh", _capsule(0.075, THIGH + 0.15), suit, mass * 0.125))
		_shins.append(_part("Shin", _capsule(0.065, SHIN + 0.13), boots, mass * 0.0875))
	torso.continuous_cd = true
	# Joints remember the parts' places when made, so make them in the rest pose.
	_angles.fill(0.0)
	_place(Transform3D.IDENTITY)
	_joint(torso, head, Vector3(0, 0.35, 0.06), Vector3.UP, 0.7, 0.7)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var hip := Vector3(s * HIP.x, HIP.y, HIP.z)
		_joint(torso, _thighs[i], hip, Vector3.DOWN, 1.4, 0.5)
		_joint(_thighs[i], _shins[i], hip + Vector3(0, -THIGH, 0), Vector3.DOWN, 1.2, 0.15)
	_set_physical(false)


## Poses the upright body on [param frame] (the player's centre, facing with the walking
## frame). [param phase] runs the stride, [param walk] 0..1 how fast, [param tuck] 0..1
## how tightly the knees pull up (rolling in the air).
func pose(frame: Transform3D, phase: float, walk: float, tuck: float, delta: float) -> void:
	if limp:
		return
	var swing := sin(phase) * 0.55 * walk
	var k := GravityMath.blend(14.0, delta)
	# Thighs swing opposite; each knee bends while its leg swings forward. Tucking pulls both up.
	_angles[0] = lerpf(_angles[0], lerpf(swing, 1.1, tuck), k)
	_angles[1] = lerpf(_angles[1], lerpf(-swing, 1.1, tuck), k)
	_angles[2] = lerpf(_angles[2], lerpf(maxf(0.0, cos(phase)) * 0.9 * walk, 1.7, tuck), k)
	_angles[3] = lerpf(_angles[3], lerpf(maxf(0.0, -cos(phase)) * 0.9 * walk, 1.7, tuck), k)
	_place(frame)


## Goes limp: every part becomes a rigid body moving with [param velocity] and spinning
## at [param omega] about [param center].
func go_limp(velocity: Vector3, omega: Vector3, center: Vector3) -> void:
	limp = true
	_set_physical(true)
	for b in _all():
		b.linear_velocity = velocity + omega.cross(b.global_position - center)
		b.angular_velocity = omega
	_prev_v = velocity


## Stops being a ragdoll; [method pose] takes over again.
func end_limp() -> void:
	limp = false
	_set_physical(false)


## Whether the limp body has come to rest.
func settled() -> bool:
	return torso.linear_velocity.length() < 0.6 and torso.angular_velocity.length() < 2.0


func _physics_process(_delta: float) -> void:
	if not limp:
		return
	var v := torso.linear_velocity
	var lost := (_prev_v - v).length()
	_prev_v = v
	if lost > IMPACT_MIN:
		impact.emit(lost)


func _all() -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = [torso, head]
	out.append_array(_thighs)
	out.append_array(_shins)
	return out


## Physical: real bodies that collide. Not: kinematic, touching nothing, posed by hand.
func _set_physical(on: bool) -> void:
	for b in _all():
		b.freeze = not on
		b.collision_layer = PhysicsLayers.RAGDOLL if on else 0
		b.collision_mask = (PhysicsLayers.WORLD | PhysicsLayers.CUBE) if on else 0
		b.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if on else Node.PHYSICS_INTERPOLATION_MODE_OFF
		if on:
			b.reset_physics_interpolation()


func _place(frame: Transform3D) -> void:
	torso.global_transform = Transform3D(frame.basis, frame * Vector3(0, 0.12, 0.12))
	head.global_transform = Transform3D(frame.basis, frame * Vector3(0, 0.47, 0.05))
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var hip := frame * Vector3(s * HIP.x, HIP.y, HIP.z)
		var r1 := frame.basis * Basis(Vector3.RIGHT, _angles[i])
		var knee := hip + r1 * Vector3(0, -THIGH, 0)
		_thighs[i].global_transform = Transform3D(r1, hip + r1 * Vector3(0, -THIGH * 0.5, 0))
		var r2 := frame.basis * Basis(Vector3.RIGHT, _angles[i] - _angles[i + 2])
		_shins[i].global_transform = Transform3D(r2, knee + r2 * Vector3(0, -SHIN * 0.5, 0))


func _part(part_name: String, mesh: PrimitiveMesh, mat: Material, mass_kg: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = part_name
	b.mass = mass_kg
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.angular_damp = 1.0
	b.linear_damp = 0.1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	if mesh is CapsuleMesh:
		var shape := CapsuleShape3D.new()
		shape.radius = (mesh as CapsuleMesh).radius
		shape.height = (mesh as CapsuleMesh).height
		cs.shape = shape
	else:
		var shape := SphereShape3D.new()
		shape.radius = (mesh as SphereMesh).radius
		cs.shape = shape
	b.add_child(cs)
	add_child(b)
	return b


## A cone-twist joint at [param at] (body space at rest) whose cone opens along [param axis].
func _joint(a: RigidBody3D, b: RigidBody3D, at: Vector3, axis: Vector3, swing: float, twist: float) -> void:
	var j := ConeTwistJoint3D.new()
	# The cone's axis is the joint's local X.
	j.transform = Transform3D(Basis(Quaternion(Vector3.RIGHT, axis)), at)
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, swing)
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, twist)
	add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m
