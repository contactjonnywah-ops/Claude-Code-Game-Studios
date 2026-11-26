class_name ExitDoor
extends AnimatableBody3D
## The exit door. While the plate is pressed it slides up into the wall; when the
## plate lets go it slides back down.

## The door started moving ([param opening] tells which way).
signal started(opening: bool)
## The door reached the end of its travel.
signal stopped(opening: bool)

var open := false
var _closed_y := 0.0
var _travel := 0.0
var _speed := 1.0
var _moving := false


## Builds the door's mesh and shape from [param box].
func setup(box: BoxSpec, mat: Material, speed: float) -> void:
	position = box.center
	_closed_y = box.center.y
	_travel = box.size().y + 0.1
	_speed = speed
	sync_to_physics = true
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	var mesh := BoxMesh.new()
	mesh.size = box.size()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = box.size()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)


## Opens or closes the door.
func set_open(v: bool) -> void:
	if v == open:
		return
	open = v
	_moving = true
	started.emit(open)


## Snaps shut at once (respawn).
func snap_closed() -> void:
	open = false
	_moving = false
	position.y = _closed_y


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	var target := _closed_y + (_travel if open else 0.0)
	position.y = move_toward(position.y, target, _speed * delta)
	if is_equal_approx(position.y, target):
		_moving = false
		stopped.emit(open)
