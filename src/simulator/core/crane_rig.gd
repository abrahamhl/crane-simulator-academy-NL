extends RefCounted
## Overhead (bridge) crane kinematics — bridge along X, trolley along Z,
## hoist controls cable length. Velocity commands with acceleration limits.
## Deterministic; no scene-tree dependency.

var bridge_x := 10.0
var trolley_z := 9.0
var hoist_length := 5.0          # current cable rest length, m
var rail_height := 9.0

var bridge_vel := 0.0
var trolley_vel := 0.0
var hoist_vel := 0.0             # positive = pay out (lower the hook)

var bridge_limits := Vector2(2.0, 58.0)
var trolley_limits := Vector2(1.5, 16.5)
var hoist_limits := Vector2(1.2, 8.0)

var max_bridge_speed := 0.8      # m/s — typical slow factory travel
var max_trolley_speed := 0.6
var max_hoist_speed := 0.35
var travel_accel := 0.5          # m/s^2
var hoist_accel := 0.45
var fine_factor := 0.25

var powered := true              # false until pre-use checks release controls


func step(dt: float, cmd_bridge: float, cmd_trolley: float, cmd_hoist: float,
		fine: bool = false) -> void:
	var f := fine_factor if fine else 1.0
	if not powered:
		cmd_bridge = 0.0
		cmd_trolley = 0.0
		cmd_hoist = 0.0

	bridge_vel = move_toward(bridge_vel,
		clampf(cmd_bridge, -1.0, 1.0) * max_bridge_speed * f, travel_accel * dt)
	trolley_vel = move_toward(trolley_vel,
		clampf(cmd_trolley, -1.0, 1.0) * max_trolley_speed * f, travel_accel * dt)
	hoist_vel = move_toward(hoist_vel,
		clampf(cmd_hoist, -1.0, 1.0) * max_hoist_speed * f, hoist_accel * dt)

	bridge_x += bridge_vel * dt
	if bridge_x <= bridge_limits.x or bridge_x >= bridge_limits.y:
		bridge_x = clampf(bridge_x, bridge_limits.x, bridge_limits.y)
		bridge_vel = 0.0

	trolley_z += trolley_vel * dt
	if trolley_z <= trolley_limits.x or trolley_z >= trolley_limits.y:
		trolley_z = clampf(trolley_z, trolley_limits.x, trolley_limits.y)
		trolley_vel = 0.0

	hoist_length += hoist_vel * dt
	if hoist_length <= hoist_limits.x or hoist_length >= hoist_limits.y:
		hoist_length = clampf(hoist_length, hoist_limits.x, hoist_limits.y)
		hoist_vel = 0.0


func support_point() -> Vector3:
	return Vector3(bridge_x, rail_height, trolley_z)
