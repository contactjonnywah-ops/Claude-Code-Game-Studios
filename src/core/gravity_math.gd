class_name GravityMath
extends RefCounted
## Pure physics formulas for falling bodies with quadratic air drag.
##
## Drag force is F = k v^2 with k = 0.5 * rho * CdA. Terminal speed is
## v_t = sqrt(m g / k). Falling a height h from speed v0 gives
## v^2 = v_t^2 + (v0^2 - v_t^2) * exp(-2 g h / v_t^2), which reduces to
## v^2 = v0^2 + 2 g h when there is no drag.


## The drag constant k (kg/m) in F = k v^2.
static func drag_constant(air_density: float, drag_area: float) -> float:
	return 0.5 * air_density * drag_area


## Terminal speed (m/s) of a body of [param mass] kg under [param g] with drag constant [param k].
static func terminal_speed(mass: float, g: float, k: float) -> float:
	if k <= 0.0:
		return INF
	return sqrt(mass * g / k)


## Speed (m/s) a body reaches after falling [param height] metres from speed [param v0].
static func impact_speed(height: float, g: float, mass: float, k: float, v0: float = 0.0) -> float:
	if height <= 0.0:
		return v0
	if k <= 0.0:
		return sqrt(v0 * v0 + 2.0 * g * height)
	var vt2 := mass * g / k
	return sqrt(maxf(0.0, vt2 + (v0 * v0 - vt2) * exp(-2.0 * g * height / vt2)))


## Take-off speed (m/s) to rise [param height] metres against [param g] (drag is negligible here).
static func jump_speed(g: float, height: float) -> float:
	return sqrt(2.0 * g * maxf(0.0, height))


## Acceleration (m/s^2) quadratic drag puts on a body moving at [param velocity].
static func drag_acceleration(velocity: Vector3, k: float, mass: float) -> Vector3:
	if mass <= 0.0:
		return Vector3.ZERO
	return -velocity * velocity.length() * k / mass


## How close a landing at [param speed] came to killing: 0 is harmless, 1 is lethal.
static func landing_severity(speed: float, lethal_speed: float) -> float:
	return clampf(speed / lethal_speed, 0.0, 1.0)


## Whether a landing at [param speed] kills.
static func is_lethal(speed: float, lethal_speed: float) -> bool:
	return speed > lethal_speed


## Seconds a landing knocks the player down: 0 when they land upright enough and soft
## enough. [param misalign] is how far (radians) the body still was from upright,
## [param severity] the landing's 0..1 share of lethal. Past either limit, the time runs
## from [param t_min] to [param t_max] with how bad the worse of the two was.
static func knockdown_time(misalign: float, severity: float, angle_limit: float, hurt_ratio: float,
		t_min: float, t_max: float) -> float:
	if misalign <= angle_limit and severity <= hurt_ratio:
		return 0.0
	var tilt := (misalign - angle_limit) / (PI / 2.0)
	var hard := (severity - hurt_ratio) / maxf(1.0 - hurt_ratio, 0.001)
	return lerpf(t_min, t_max, clampf(maxf(tilt, hard), 0.0, 1.0))


## One step of a falling body's spin. [param omega] is its angular velocity (rad/s, world
## axis * rate). [param steer] is the player's roll/pitch input as a world axis (length
## 0..1); while it is zero a reflex of strength [param assist] (1/s^2) turns
## [param body_up] toward [param target_up]. [param damp] (1/s) is air drag on the spin.
## Returns the new angular velocity.
## [codeblock]
## omega = GravityMath.air_spin(omega, body_up, -gdir, steer, 14.0, 9.0, 6.0, delta)
## [/codeblock]
static func air_spin(omega: Vector3, body_up: Vector3, target_up: Vector3, steer: Vector3,
		accel: float, assist: float, damp: float, dt: float) -> Vector3:
	var a := steer * accel
	if steer.is_zero_approx():
		var angle := acos(clampf(body_up.dot(target_up), -1.0, 1.0))
		var axis := body_up.cross(target_up)
		if axis.length() < 0.0001: # exactly upside down: any sideways axis will do
			axis = body_up.cross(Vector3.RIGHT if absf(body_up.x) < 0.9 else Vector3.FORWARD)
		a += axis.normalized() * angle * assist
	return omega + (a - omega * damp) * dt


## Factor that closes a share of a gap at [param rate] per second over [param dt] seconds,
## independent of the frame rate: 1 - e^(-rate * dt).
static func blend(rate: float, dt: float) -> float:
	return 1.0 - exp(-maxf(0.0, rate) * dt)
