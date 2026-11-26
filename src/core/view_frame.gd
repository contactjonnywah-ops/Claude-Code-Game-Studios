class_name ViewFrame
extends RefCounted
## The player's view frame under gravity that can point any way.
##
## [member base] turns world-up into the player's up; [member yaw] and [member pitch]
## look around inside that frame. When gravity changes, [method rebase] rolls the
## frame to the new up while keeping the look direction where the player left it.

## Pitch is kept inside +-this many radians.
const PITCH_LIMIT := 1.5

var base := Quaternion.IDENTITY
var yaw := 0.0
var pitch := 0.0


## Back to world-up, facing along [param start_yaw].
func reset(start_yaw: float) -> void:
	base = Quaternion.IDENTITY
	yaw = start_yaw
	pitch = 0.0


## Turns the view by the given angles (radians), clamping pitch.
func add_look(d_yaw: float, d_pitch: float) -> void:
	yaw = wrapf(yaw + d_yaw, -PI, PI)
	pitch = clampf(pitch + d_pitch, -PITCH_LIMIT, PITCH_LIMIT)


## The full look rotation (camera orientation).
func look() -> Quaternion:
	return base * Quaternion.from_euler(Vector3(pitch, yaw, 0.0))


## The look rotation without pitch: the frame walking happens in.
func flat() -> Quaternion:
	return base * Quaternion.from_euler(Vector3(0.0, yaw, 0.0))


## Where the eye points.
func forward() -> Vector3:
	return look() * Vector3.FORWARD


## The player's up.
func up() -> Vector3:
	return base * Vector3.UP


## Rolls the frame so [param new_up] becomes up, keeping the look direction.
func rebase(new_up: Vector3) -> void:
	var to := new_up.normalized()
	var from := up()
	var fwd := forward()
	var arc: Quaternion
	if from.dot(to) > 0.99999:
		return
	if from.dot(to) < -0.99999:
		# Straight overhead: half a roll about the walking direction keeps the facing.
		arc = Quaternion((flat() * Vector3.FORWARD).normalized(), PI)
	else:
		arc = Quaternion(from, to)
	base = (arc * base).normalized()
	var d := base.inverse() * fwd
	pitch = clampf(asin(clampf(d.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)
	yaw = atan2(-d.x, -d.z)
