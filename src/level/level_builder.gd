class_name LevelBuilder
extends RefCounted
## Turns [LevelData] into nodes: static bodies, meshes, the grip panels and the lights.
##
## Usage:
## [codeblock]
## var built := LevelBuilder.build(level, materials, world_root)
## var plate_mesh: MeshInstance3D = built.plate_pad
## [/codeblock]

## Group every grip panel body is in; the gun checks it.
const GRIP_GROUP := &"grip_panel"

var root: Node3D
var plate_pad: MeshInstance3D
var lamps: Array[OmniLight3D] = []


## Builds the level under [param parent] and returns handles to the parts that change.
static func build(level: LevelData, mats: SurfaceMaterials, parent: Node3D) -> LevelBuilder:
	var b := LevelBuilder.new()
	b.root = Node3D.new()
	b.root.name = "Level"
	parent.add_child(b.root)

	var solid := StaticBody3D.new()
	solid.name = "Solid"
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	solid.physics_material_override = _steel()
	b.root.add_child(solid)
	for box in level.walls:
		_add_box(solid, box, mats.floor_tile if level.is_floor(box) else mats.wall, true)
	for box in level.blocks:
		_add_box(solid, box, mats.block, true)
	for box in level.trims:
		_add_box(solid, box, mats.trim, true)
	for box in level.tube:
		_add_box(solid, box, mats.glass, true).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box(solid, level.end_glow, mats.exit_glow, true)

	var grip := StaticBody3D.new()
	grip.name = "GripPanels"
	grip.collision_layer = PhysicsLayers.GRIP
	grip.collision_mask = 0
	grip.add_to_group(GRIP_GROUP)
	b.root.add_child(grip)
	for box in level.panels:
		_add_box(grip, box, mats.dark, true)

	b.plate_pad = _add_box(b.root, level.plate_pad, mats.plate, false)
	_add_box(b.root, level.plate_mark, mats.plate, false)

	var i := 0
	for p in level.lights:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 16.0
		l.omni_attenuation = 1.2
		l.light_energy = 2.8
		l.light_color = Color("f2f7ff") # cool clinical white
		l.shadow_enabled = i % 2 == 0
		l.shadow_bias = 0.05
		b.root.add_child(l)
		b.lamps.append(l)
		l.position = _add_fixture(b.root, p, level, mats) # shine from the fixture
		i += 1
	return b


## Mounts a glowing light fixture on the surface nearest [param light], looking straight
## along the six axes; never on a grip panel, where it would get in the way of a shot.
## Returns where the light should sit: just in front of the fixture (or where it was).
static func _add_fixture(parent: Node3D, light: Vector3, level: LevelData, mats: SurfaceMaterials) -> Vector3:
	var best := INF
	var dir := Vector3.ZERO
	for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var dist := _distance_to_solid(light, d, level)
		if dist < best and not _on_panel(light + d * dist, level):
			best = dist
			dir = d
	if dir == Vector3.ZERO:
		return light
	var axis := dir.abs().max_axis_index()
	var size := Vector3(1.6, 1.6, 1.6)
	size[axis] = 0.04
	size[(axis + 2) % 3] = 0.45 # a strip: long along z on ceilings, upright on side walls
	var hit := light + dir * best
	for part: Array in [[mats.trim, size + Vector3.ONE * 0.12 - dir.abs() * 0.1, 0.03], [mats.lamp, size, 0.065]]:
		var mesh := BoxMesh.new()
		mesh.size = part[1]
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = part[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = hit - dir * float(part[2])
		parent.add_child(mi)
	return hit - dir * 0.6


## How far from [param p] along axis direction [param d] the first wall or block face is.
static func _distance_to_solid(p: Vector3, d: Vector3, level: LevelData) -> float:
	var axis := d.abs().max_axis_index()
	var best := INF
	for box: BoxSpec in level.walls + level.blocks:
		var lo := box.center - box.half
		var hi := box.center + box.half
		var across := true
		for a in 3:
			if a != axis and (p[a] < lo[a] or p[a] > hi[a]):
				across = false
		if not across:
			continue
		var dist := ((lo[axis] if d[axis] > 0.0 else hi[axis]) - p[axis]) * d[axis]
		if dist > 0.0:
			best = minf(best, dist)
	return best


static func _on_panel(p: Vector3, level: LevelData) -> bool:
	for panel in level.panels:
		if AABB(panel.center - panel.half, panel.size()).grow(0.9).has_point(p):
			return true
	return false


## Crate-on-steel contact; the crate's own material sets the pair.
static func _steel() -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.0
	return pm


## Adds a mesh for [param box] under [param parent]; with [param collide], a matching shape too.
static func _add_box(parent: Node3D, box: BoxSpec, mat: Material, collide: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box.size()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = box.transform()
	parent.add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = box.size()
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = box.transform()
		parent.add_child(cs)
	return mi
