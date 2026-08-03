extends RefCounted
## Objectives — pure pickup -> transport -> deliver scoring for one scenario.
## No scene dependency: fed load position/swing/collision counts each frame,
## exposes phase + score. Unit tested directly in tests/module_tests.gd.
##
## "Pickup"/"delivery" are defined as: load's horizontal position within the
## zone radius AND load height within tolerance of the floor, held for
## `dwell_time_s` continuously. This reuses the existing hoist/bridge/trolley
## model without inventing a separate hook-attach mechanic.

enum Phase { NOT_STARTED, CARRYING, DELIVERED }

var scenario: Dictionary = {}
var phase: int = Phase.NOT_STARTED
var elapsed_s := 0.0
var max_swing_deg := 0.0
var collisions := 0
var violations := 0
var near_misses := 0

var _dwell_timer := 0.0


func load_scenario(data: Dictionary) -> void:
	scenario = data
	reset()


func reset() -> void:
	phase = Phase.NOT_STARTED
	elapsed_s = 0.0
	max_swing_deg = 0.0
	collisions = 0
	violations = 0
	near_misses = 0
	_dwell_timer = 0.0


static func load_from_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _zone_dist(x: float, z: float, zone: Dictionary) -> float:
	return Vector2(x - float(zone.x), z - float(zone.z)).length()


## Advances the scenario by one tick. new_collisions/new_violations/
## new_near_misses are counts observed THIS tick (added to the running
## total), not cumulative totals. new_near_misses defaults to 0 so existing
## callers that don't track it (older tests) keep working unmodified.
func update(delta: float, load_x: float, load_z: float, height_over_floor: float,
		swing_deg: float, new_collisions: int, new_violations: int,
		new_near_misses: int = 0) -> void:
	if scenario.is_empty() or phase == Phase.DELIVERED:
		return
	elapsed_s += delta
	collisions += new_collisions
	violations += new_violations
	near_misses += new_near_misses
	if phase == Phase.CARRYING:
		max_swing_deg = maxf(max_swing_deg, swing_deg)

	var target_zone: Dictionary = scenario.pickup if phase == Phase.NOT_STARTED else scenario.dropoff
	var height_tol: float = scenario.get("pickup_height_tolerance_m", 1.2)
	var in_position := _zone_dist(load_x, load_z, target_zone) <= float(target_zone.radius) \
		and height_over_floor <= height_tol
	_dwell_timer = _dwell_timer + delta if in_position else 0.0

	var dwell_needed: float = scenario.get("dwell_time_s", 1.0)
	if _dwell_timer >= dwell_needed:
		_dwell_timer = 0.0
		if phase == Phase.NOT_STARTED:
			phase = Phase.CARRYING
		elif phase == Phase.CARRYING:
			phase = Phase.DELIVERED


func score() -> Dictionary:
	var swing_limit: float = scenario.get("max_swing_deg_for_success", 999.0)
	return {
		"time_s": elapsed_s,
		"max_swing_deg": max_swing_deg,
		"collisions": collisions,
		"violations": violations,
		"near_misses": near_misses,
		"passed": phase == Phase.DELIVERED and max_swing_deg <= swing_limit
			and collisions == 0 and violations == 0,
	}


func phase_name() -> String:
	match phase:
		Phase.NOT_STARTED: return "not_started"
		Phase.CARRYING: return "carrying"
		Phase.DELIVERED: return "delivered"
		_: return "?"
