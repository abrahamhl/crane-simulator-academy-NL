extends RefCounted
## ScenarioRunner — phase tracking and scoring for one job.
##
## Generalises the slice-001 `objectives.gd` (pick up here, put down there)
## to everything the simulator now models: hazard zones the load must not
## cross, seconds spent overloaded or unstable, placement accuracy, and the
## case where the CORRECT answer is to refuse the lift.
##
## Pure logic, no scene dependency: fed a state dictionary each tick, exposes
## phase, live counters and a final result. Unit tested directly.
##
## Scoring is transparent by design — every deduction is itemised in
## `breakdown()` so a debrief can say exactly what cost the points, and the
## per-event values live in AppSettings.PENALTY where an instructor can read
## them. (The commercial assessment model, with its competency weighting and
## validated thresholds, is a separate product and is not in this repository.)

enum Phase { NOT_STARTED, CARRYING, DELIVERED, STOPPED_WORK, FAILED }

var scenario: Dictionary = {}
var success: Dictionary = {}
var rules: Dictionary = {}

var phase: int = Phase.NOT_STARTED
var elapsed_s := 0.0
var max_swing_deg := 0.0
var collisions := 0
var violations := 0
var near_misses := 0
var overload_s := 0.0
var unstable_s := 0.0
var over_wind_s := 0.0
var placement_error_m := -1.0
var violated_keys: Dictionary = {}    # hazard key -> count, for the debrief
var failure_reason := ""

var _dwell := 0.0
var _finished := false


func load_scenario(data: Dictionary) -> void:
	scenario = data
	success = ScenarioDB.success_of(data)
	rules = ScenarioDB.rules_of(data)
	reset()


func reset() -> void:
	phase = Phase.NOT_STARTED
	elapsed_s = 0.0
	max_swing_deg = 0.0
	collisions = 0
	violations = 0
	near_misses = 0
	overload_s = 0.0
	unstable_s = 0.0
	over_wind_s = 0.0
	placement_error_m = -1.0
	violated_keys.clear()
	failure_reason = ""
	_dwell = 0.0
	_finished = false


func is_finished() -> bool:
	return _finished


## One tick. `s` carries everything scoring depends on:
##   load_x, load_z, load_height_m, swing_deg,
##   new_collisions, new_violations, new_near_misses,
##   overloaded (bool), unstable (bool), over_wind (bool),
##   hazard_hit (String or ""), fail_on_violation (bool)
func update(delta: float, s: Dictionary) -> void:
	if _finished:
		return
	elapsed_s += delta

	var nc := int(s.get("new_collisions", 0))
	var nv := int(s.get("new_violations", 0))
	collisions += nc
	violations += nv
	near_misses += int(s.get("new_near_misses", 0))

	var hazard := String(s.get("hazard_hit", ""))
	if hazard != "":
		violated_keys[hazard] = int(violated_keys.get(hazard, 0)) + 1

	if bool(s.get("overloaded", false)):
		overload_s += delta
	if bool(s.get("unstable", false)):
		unstable_s += delta
	if bool(s.get("over_wind", false)):
		over_wind_s += delta

	if phase == Phase.CARRYING:
		max_swing_deg = maxf(max_swing_deg, float(s.get("swing_deg", 0.0)))

	# Assessment mode ends the run on the first real violation, exactly as a
	# practical test would. Guided and standard modes let it continue so the
	# learner can finish the job and read the debrief.
	if bool(s.get("fail_on_violation", false)) and (nv > 0 or nc > 0):
		failure_reason = hazard if hazard != "" else "score_violations"
		phase = Phase.FAILED
		_finished = true
		return

	_advance_phase(delta, s)


func _advance_phase(delta: float, s: Dictionary) -> void:
	if phase == Phase.DELIVERED or phase == Phase.STOPPED_WORK:
		return
	var target: Dictionary = scenario.get("pickup", {}) if phase == Phase.NOT_STARTED \
		else scenario.get("dropoff", {})
	if target.is_empty():
		return

	var dist := Vector2(float(s.get("load_x", 0.0)) - float(target.x),
		float(s.get("load_z", 0.0)) - float(target.z)).length()
	var in_zone := dist <= float(target.get("radius", 1.8)) \
		and float(s.get("load_height_m", 99.0)) <= float(success.height_tol_m)

	_dwell = _dwell + delta if in_zone else 0.0
	if _dwell < float(success.dwell_s):
		return

	_dwell = 0.0
	if phase == Phase.NOT_STARTED:
		phase = Phase.CARRYING
	else:
		placement_error_m = dist
		phase = Phase.DELIVERED
		_finished = true


## The operator judged the conditions unsafe and stopped. On a scenario whose
## rules expect a refusal this is the PASS condition; anywhere else it ends
## the run without a delivery.
func stop_work() -> void:
	if _finished:
		return
	phase = Phase.STOPPED_WORK
	_finished = true


func phase_name() -> String:
	match phase:
		Phase.CARRYING: return "carrying"
		Phase.DELIVERED: return "delivered"
		Phase.STOPPED_WORK: return "stopped_work"
		Phase.FAILED: return "failed"
		_: return "not_started"


# --- scoring -------------------------------------------------------------------

## Itemised deductions, in the order they should be shown in the debrief.
func breakdown() -> Array:
	var p := AppSettings.PENALTY
	var out: Array = []
	if collisions > 0:
		out.append({"key": "score_hits", "count": collisions,
			"points": -float(collisions) * p.collision})
	if violations > 0:
		out.append({"key": "score_violations", "count": violations,
			"points": -float(violations) * p.violation})
	if near_misses > 0:
		out.append({"key": "score_near_miss", "count": near_misses,
			"points": -float(near_misses) * p.near_miss})
	if overload_s > 0.05:
		out.append({"key": "score_overload", "count": int(ceil(overload_s)),
			"points": -overload_s * p.overload_second})
	if unstable_s > 0.05:
		out.append({"key": "stab_critical", "count": int(ceil(unstable_s)),
			"points": -unstable_s * p.unstable_second})
	if over_wind_s > 0.05:
		out.append({"key": "over_wind", "count": int(ceil(over_wind_s)),
			"points": -over_wind_s * p.over_wind_second})
	if max_swing_deg > float(success.max_swing_deg):
		out.append({"key": "score_swing", "count": int(max_swing_deg),
			"points": -(max_swing_deg - float(success.max_swing_deg)) * 12.0})
	var over_time := elapsed_s - float(success.time_target_s)
	if over_time > 0.0:
		out.append({"key": "score_time", "count": int(over_time),
			"points": -over_time * 1.5})
	return out


func points() -> float:
	var total := AppSettings.BASE_POINTS
	for row in breakdown():
		total += float(row.points)
	# Placement accuracy is a bonus, not a penalty: hitting the middle of the
	# zone should be worth more than clipping its edge.
	if placement_error_m >= 0.0:
		var tol: float = maxf(0.2, float(success.placement_tol_m))
		if tol > 0.0:
			total += clampf(1.0 - placement_error_m / tol, 0.0, 1.0) * 120.0
	total *= float(GameState.difficulty_config().get("score_multiplier", 1.0))
	return maxf(0.0, total)


## Did this run pass? Refusal scenarios invert the test: stopping is the pass
## and delivering the load is the failure.
func passed() -> bool:
	if bool(rules.get("stop_work_expected", false)):
		return phase == Phase.STOPPED_WORK
	if phase != Phase.DELIVERED:
		return false
	if collisions > int(success.max_collisions):
		return false
	if violations > int(success.max_violations):
		return false
	if max_swing_deg > float(success.max_swing_deg):
		return false
	if bool(rules.get("no_overload", true)) and overload_s > 0.5:
		return false
	if points() < AppSettings.PASS_POINTS:
		return false
	return true


## Live counters for the HUD.
func live() -> Dictionary:
	return {
		"time_s": elapsed_s,
		"max_swing_deg": max_swing_deg,
		"collisions": collisions,
		"violations": violations,
		"near_misses": near_misses,
		"overload_s": overload_s,
		"unstable_s": unstable_s,
		"phase": phase_name(),
	}


## The full result, persisted into the learner's profile and shown on the
## results screen.
func result() -> Dictionary:
	return {
		"scenario_id": String(scenario.get("id", "")),
		"passed": passed(),
		"points": points(),
		"phase": phase_name(),
		"time_s": elapsed_s,
		"max_swing_deg": max_swing_deg,
		"collisions": collisions,
		"violations": violations,
		"near_misses": near_misses,
		"overload_s": overload_s,
		"unstable_s": unstable_s,
		"over_wind_s": over_wind_s,
		"placement_error_m": placement_error_m,
		"violated": violated_keys.duplicate(),
		"failure_reason": failure_reason,
		"breakdown": breakdown(),
		"difficulty": GameState.difficulty,
	}
