class_name BoxSpec
extends RefCounted
## One box of level geometry: a centre, half extents and a turn about z.

var center := Vector3.ZERO
var half := Vector3.ONE * 0.5
## Radians about the z axis.
var rot := 0.0


## Builds a box from [x0, x1, y0, y1, z0, z1] with an optional 7th value, the turn.
static func from_corners(c: Array) -> BoxSpec:
	assert(c.size() >= 6, "A box needs six corner values")
	var b := BoxSpec.new()
	b.center = Vector3((c[0] + c[1]) * 0.5, (c[2] + c[3]) * 0.5, (c[4] + c[5]) * 0.5)
	b.half = Vector3(absf(c[1] - c[0]) * 0.5, absf(c[3] - c[2]) * 0.5, absf(c[5] - c[4]) * 0.5)
	b.rot = float(c[6]) if c.size() > 6 else 0.0
	return b


## Full edge lengths.
func size() -> Vector3:
	return half * 2.0


## The box's transform in the world.
func transform() -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, rot), center)


## Whether [param p] is inside the box, ignoring its turn (used for trigger zones).
func contains(p: Vector3) -> bool:
	var d := (p - center).abs()
	return d.x < half.x and d.y < half.y and d.z < half.z
