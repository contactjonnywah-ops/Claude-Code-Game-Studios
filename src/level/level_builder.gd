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
		_add_box(solid, box, mats.wall, true)
	for box in level.blocks:
		_add_box(solid, box, mats.block, true)
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
		l.light_energy = 2.2
		l.light_color = Color("fff6ea")
		l.shadow_enabled = i % 2 == 0
		l.shadow_bias = 0.05
		b.root.add_child(l)
		b.lamps.append(l)
		i += 1
	return b


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
