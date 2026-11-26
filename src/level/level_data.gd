class_name LevelData
extends RefCounted
## The three rooms, read from [code]assets/data/level_rooms.json[/code].
##
## Rooms run along +z (metres). Room 1: z -14..-2. Room 2, a tall shaft: z -1..11.
## Room 3, on the upper floor (y 16): z 12..26. Dark panels are the only surfaces
## the gravity gun grips; they are aimed at, never collided with.

## Where the shipped level lives.
const DEFAULT_PATH := "res://assets/data/level_rooms.json"

var walls: Array[BoxSpec] = []
var blocks: Array[BoxSpec] = []
var tube: Array[BoxSpec] = []
var panels: Array[BoxSpec] = []
var end_glow: BoxSpec
var door: BoxSpec
var plate_zone: BoxSpec
var plate_pad: BoxSpec
var plate_mark: BoxSpec
## Which way the plate's surface faces; only weight resting on it, pressing against
## this, presses it.
var plate_up := Vector3.UP
## The box every wall fits in: anything past it has clipped out of the level.
var bounds := AABB()
var cube_start := Vector3.ZERO
var win_z := 0.0
## Each room: { "name": String, "start": Vector3, "from_z": float }.
var rooms: Array[Dictionary] = []
var lights: Array[Vector3] = []
var title_camera_position := Vector3.ZERO
var title_camera_target := Vector3.ZERO


## Loads the level from a JSON file.
static func load_file(path: String = DEFAULT_PATH) -> LevelData:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Level file missing or empty: %s" % path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Level file is not a JSON object: %s" % path)
	return from_dict(parsed)


## Builds the level from a parsed dictionary.
static func from_dict(d: Dictionary) -> LevelData:
	var L := LevelData.new()
	for c: Array in d["walls"]:
		L.walls.append(BoxSpec.from_corners(c))
	for c: Array in d["blocks"]:
		L.blocks.append(BoxSpec.from_corners(c))
	for c: Array in d["tube"]:
		L.tube.append(BoxSpec.from_corners(c))
	for p: Dictionary in d["panels"]:
		var b := BoxSpec.from_corners(p["box"])
		if p.has("center"):
			b.center = _vec(p["center"])
		L.panels.append(b)
	L.end_glow = BoxSpec.from_corners(d["end_glow"])
	L.door = BoxSpec.from_corners(d["door"])
	L.plate_zone = BoxSpec.from_corners(d["plate_zone"])
	L.plate_pad = BoxSpec.from_corners(d["plate_pad"])
	L.plate_mark = BoxSpec.from_corners(d["plate_mark"])
	if d.has("plate_up"):
		L.plate_up = _vec(d["plate_up"]).normalized()
	for i in L.walls.size():
		var w := AABB(L.walls[i].center - L.walls[i].half, L.walls[i].size())
		L.bounds = w if i == 0 else L.bounds.merge(w)
	L.cube_start = _vec(d["cube_start"])
	L.win_z = float(d["win_z"])
	for r: Dictionary in d["rooms"]:
		L.rooms.append({ "name": str(r["name"]), "start": _vec(r["start"]), "from_z": float(r["from_z"]) })
	for l: Array in d["lights"]:
		L.lights.append(_vec(l))
	L.title_camera_position = _vec(d["title_camera"]["position"])
	L.title_camera_target = _vec(d["title_camera"]["look_at"])
	return L


## Which room a body at [param z] is in, never going back below [param current].
func room_at(z: float, current: int) -> int:
	var r := current
	while r < rooms.size() - 1 and z > float(rooms[r + 1]["from_z"]):
		r += 1
	return r


## Whether something at [param p] presses the plate. [param resting] says it rests on a
## surface facing [member plate_up]: something just passing through, or floating over the
## plate in the beam, does not press it.
func presses_plate(p: Vector3, resting: bool = true) -> bool:
	return resting and plate_zone.contains(p)


## Whether [param p] is more than [param margin] metres outside the level's walls.
func out_of_bounds(p: Vector3, margin: float) -> bool:
	return not bounds.grow(margin).has_point(p)


static func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
