extends SceneTree
## Deterministic pure-logic tests (no scene, no autoloads).
##
## Autoloads are NOT available under `--script`, so everything tested here must
## be reachable without them. Modules that legitimately depend on an autoload
## (ScenarioRunner, Guidance's text, the HUD) are covered by the scene selftest
## in selftest_driver.gd instead — the split is deliberate, not an omission.
##
## Run:  godot --headless --path src/simulator --script res://tests/module_tests.gd -- --out=ABS_DIR
## Exits 0 on full pass / 1 on any failure; writes MODULE_TEST_RESULTS.json.

const CableLoadSimScript := preload("res://core/cable_load_sim.gd")
const WindModelScript := preload("res://core/wind_model.gd")
const TelemetryScript := preload("res://core/telemetry.gd")
const ObjectivesScript := preload("res://core/objectives.gd")
const MachineAccessScript := preload("res://core/machine_access.gd")
const LoadBodyScript := preload("res://core/load_body.gd")
const MachineRigScript := preload("res://core/machine_rig.gd")
const CatalogScript := preload("res://core/machine_catalog.gd")
const LoadChartScript := preload("res://core/load_chart.gd")
const RiggingScript := preload("res://core/rigging.gd")
const StabilityScript := preload("res://core/stability_model.gd")
const GuidanceScript := preload("res://core/guidance.gd")

const DT := 1.0 / 120.0

var results: Array = []


func _initialize() -> void:
	_test_period_scaling()
	_test_seeded_determinism_and_wind_difference()
	_test_zero_wind_determinism()
	_test_wind_lateral_displacement()
	_test_nan_stress()

	# Hito 1 additions — pure logic, no scene required (see DECISIONS.md DEC-010).
	_test_objectives_pickup_and_delivery()
	_test_objectives_swing_failure()
	_test_machine_access_state_machine()
	_test_load_body_collision_math()
	_test_load_body_impact_response()
	_test_load_safety_radius()

	# Multi-machine release: kinematics, load charts, rigging, stability and
	# the guidance state machine that replaced the old fixed tutorial.
	_test_catalog_integrity()
	_test_rig_axis_limits_and_accel()
	_test_rig_kinematics_per_class()
	_test_rig_outrigger_interlock()
	_test_load_chart_lookup()
	_test_load_chart_planning()
	_test_rigging_math()
	_test_stability_model()
	_test_guidance_state_machine()

	var all_ok := true
	for r in results:
		if not r.ok:
			all_ok = false
	var summary := {
		"suite": "slice001_module_tests",
		"date": "2026-07-17",
		"godot": Engine.get_version_info().string,
		"total": results.size(),
		"passed": results.filter(func(r): return r.ok).size(),
		"all_ok": all_ok,
		"tests": results,
	}
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if out_dir != "":
		var f := FileAccess.open(out_dir.path_join("MODULE_TEST_RESULTS.json"),
			FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(summary, "  "))
			f.close()
	print("[MODULE_TESTS] %d/%d passed -> %s"
		% [summary.passed, summary.total, "PASS" if all_ok else "FAIL"])
	quit(0 if all_ok else 1)


func _record(id: String, ok: bool, detail: String) -> void:
	results.append({"id": id, "ok": ok, "detail": detail})
	print("[MODULE_TESTS] %s %s -- %s" % ["[OK]  " if ok else "[FAIL]", id, detail])


## Small-angle pendulum, no drag: measured period via zero crossings.
func _measure_period(length: float) -> float:
	var sim = CableLoadSimScript.new()
	sim.setup(Vector3.ZERO, length, 500.0, 0.0, 0.0, DT)
	sim.displace_angle(deg_to_rad(5.0))
	var crossings := PackedFloat64Array()
	var prev_x: float = sim.load_pos.x
	var steps := int(round(40.0 / DT))
	for i in steps:
		sim.step(Vector3.ZERO, Vector3.ZERO)
		var x: float = sim.load_pos.x
		if (prev_x < 0.0) != (x < 0.0):
			var frac := prev_x / (prev_x - x)
			crossings.append((float(i) + frac) * DT)
		prev_x = x
	if crossings.size() < 4:
		return -1.0
	return 2.0 * (crossings[-1] - crossings[0]) / float(crossings.size() - 1)


func _test_period_scaling() -> void:
	var t4 := _measure_period(4.0)
	var t8 := _measure_period(8.0)
	var ideal4 := TAU * sqrt(4.0 / 9.80665)
	var ratio := t8 / t4
	_record("longer_cable_longer_period", t8 > t4 and t4 > 0.0,
		"T(4m)=%.4f s, T(8m)=%.4f s" % [t4, t8])
	_record("period_matches_theory",
		absf(t4 / ideal4 - 1.0) < 0.02 and absf(ratio / sqrt(2.0) - 1.0) < 0.02,
		"T(4m) vs 2*PI*sqrt(L/g)=%.4f s (err %.2f%%); T8/T4=%.4f vs sqrt(2) (err %.2f%%)"
		% [ideal4, absf(t4 / ideal4 - 1.0) * 100.0,
			ratio, absf(ratio / sqrt(2.0) - 1.0) * 100.0])


## Scripted 20 s run: moving support, hoisting cable, optional seeded wind.
func _scripted_hash(seed_value: int, with_wind: bool) -> String:
	var sim = CableLoadSimScript.new()
	sim.setup(Vector3(10.0, 9.0, 9.0), 5.0, 500.0, 2.0, 1.2, DT)
	var wm = WindModelScript.new()
	wm.setup(seed_value, 90.0, 6.0, 2.0, 3.0)
	var tel = TelemetryScript.new()
	var steps := int(round(20.0 / DT))
	for i in steps:
		wm.step(DT)
		var w: Vector3 = wm.wind() if with_wind else Vector3.ZERO
		var t := float(i) * DT
		var sup := Vector3(10.0 + minf(t, 5.0) * 0.4, 9.0,
			9.0 + sin(t * 0.5) * 1.5)
		sim.cable_length = 5.0 - minf(t * 0.1, 2.0)
		sim.step(sup, w)
		tel.record(t, sim.load_pos, sim.support_pos, sim.tension,
			rad_to_deg(sim.swing_angle_rad()), w)
	return tel.state_hash()


func _test_seeded_determinism_and_wind_difference() -> void:
	var a := _scripted_hash(12345, true)
	var b := _scripted_hash(12345, true)
	var c := _scripted_hash(12345, false)
	_record("seeded_run_deterministic", a == b and a != "",
		"hash A=%s, hash B=%s" % [a, b])
	_record("wind_changes_trajectory", a != c,
		"wind hash=%s vs no-wind hash=%s" % [a, c])


func _test_zero_wind_determinism() -> void:
	var a := _scripted_hash(1, false)
	var b := _scripted_hash(999, false)  # seed must not matter with wind off
	_record("zero_wind_deterministic", a == b,
		"no-wind hashes across different seeds: %s vs %s" % [a, b])


## Steady wind (sigma=0) toward +X must push the hanging load laterally.
func _test_wind_lateral_displacement() -> void:
	var offsets := []
	for windy in [false, true]:
		var sim = CableLoadSimScript.new()
		sim.setup(Vector3.ZERO, 6.0, 500.0, 2.0, 1.2, DT)
		var wm = WindModelScript.new()
		wm.setup(1, 0.0, 8.0, 0.0, 3.0)
		var steps := int(round(30.0 / DT))
		var acc := 0.0
		var n := 0
		for i in steps:
			wm.step(DT)
			sim.step(Vector3.ZERO, wm.wind() if windy else Vector3.ZERO)
			if i >= steps / 2:
				acc += sim.load_pos.x
				n += 1
		offsets.append(acc / float(n))
	_record("wind_causes_lateral_displacement",
		absf(offsets[0]) < 1e-6 and offsets[1] > 0.05,
		"mean x offset: %.6f m (no wind) vs %.4f m (8 m/s wind +X)"
		% [offsets[0], offsets[1]])


## Aggressive support motion + hoist sweep + strong gusts: state stays finite.
func _test_nan_stress() -> void:
	var sim = CableLoadSimScript.new()
	sim.setup(Vector3.ZERO, 8.0, 300.0, 2.5, 1.3, DT)
	var wm = WindModelScript.new()
	wm.setup(999, 45.0, 15.0, 5.0, 1.5)
	var steps := int(round(30.0 / DT))
	var violations := 0
	for i in steps:
		var t := float(i) * DT
		wm.step(DT)
		var sup := Vector3(sin(t * TAU * 1.0) * 2.0, sin(t * 3.1) * 0.5,
			cos(t * TAU * 0.7) * 2.0)
		sim.cable_length = 8.0 - 6.8 * absf(sin(t * 0.3))
		sim.step(sup, wm.wind())
		if not (sim.load_pos.is_finite() and sim.load_vel.is_finite()
				and is_finite(sim.tension)):
			violations += 1
	_record("no_nan_or_infinity_under_stress", violations == 0,
		"%d non-finite observations over %d steps (slack/shock + gusts + hoist sweep)"
		% [violations, steps])


func _sc001_test_scenario() -> Dictionary:
	return {
		"pickup": {"x": 0.0, "z": 0.0, "radius": 1.0},
		"dropoff": {"x": 10.0, "z": 0.0, "radius": 1.0},
		"pickup_height_tolerance_m": 1.0,
		"dwell_time_s": 1.0,
		"max_swing_deg_for_success": 2.0,
	}


## Load stays away -> NOT_STARTED; sits over pickup -> CARRYING; sits over
## drop-off -> DELIVERED, with a clean pass (no collisions, swing in budget).
func _test_objectives_pickup_and_delivery() -> void:
	var obj = ObjectivesScript.new()
	obj.load_scenario(_sc001_test_scenario())
	var dt := 1.0 / 60.0
	for i in 30:
		obj.update(dt, 5.0, 5.0, 5.0, 0.0, 0, 0)
	var phase0 := obj.phase_name()
	for i in 90:
		obj.update(dt, 0.0, 0.0, 0.5, 0.0, 0, 0)
	var phase1 := obj.phase_name()
	for i in 90:
		obj.update(dt, 10.0, 0.0, 0.5, 0.5, 0, 0)
	var phase2 := obj.phase_name()
	var sc: Dictionary = obj.score()
	_record("objectives_pickup_then_delivery",
		phase0 == "not_started" and phase1 == "carrying" and phase2 == "delivered" and sc.passed,
		"phases: %s -> %s -> %s, score.passed=%s (max_swing=%.2f)"
		% [phase0, phase1, phase2, sc.passed, sc.max_swing_deg])


## Same route, but swing exceeds the 2 deg budget while carrying: delivered,
## yet marked as a failed lift.
func _test_objectives_swing_failure() -> void:
	var obj = ObjectivesScript.new()
	obj.load_scenario(_sc001_test_scenario())
	var dt := 1.0 / 60.0
	for i in 90:
		obj.update(dt, 0.0, 0.0, 0.5, 0.0, 0, 0)
	for i in 90:
		obj.update(dt, 10.0, 0.0, 0.5, 5.0, 0, 0)
	var sc: Dictionary = obj.score()
	_record("objectives_fails_on_excess_swing",
		obj.phase_name() == "delivered" and not sc.passed,
		"delivered=%s passed=%s max_swing=%.2f (limit 2.0)"
		% [obj.phase_name() == "delivered", sc.passed, sc.max_swing_deg])


## Approach -> pick up pendant (instant) -> controlling -> put down (instant)
## -> outside, driven purely by position + delta, no scene. This crane is
## pendant-operated from the floor — there is nothing to climb (DEC-014).
func _test_machine_access_state_machine() -> void:
	var access = MachineAccessScript.new()
	var dt := 1.0 / 60.0
	var access_point := Vector3(1.0, 0.0, 9.0)
	var radius := 1.8

	access.update(dt, Vector3(20.0, 0.0, 20.0), access_point, radius)
	var s0 := access.state_name()
	access.update(dt, access_point, access_point, radius)
	var s1 := access.state_name()
	var interacted := access.try_interact()
	var s2 := access.state_name()
	# While controlling, update() must ignore player position (the operator is
	# standing still holding the pendant) — feed a far-away position to prove it.
	access.update(dt, Vector3(20.0, 0.0, 20.0), access_point, radius)
	var s3 := access.state_name()
	var exited := access.try_exit()
	var s4 := access.state_name()
	# Putting the pendant down falls back to OUTSIDE; still standing right
	# there re-detects IN_ZONE on the very next update() — step away first.
	access.update(dt, Vector3(20.0, 0.0, 20.0), access_point, radius)
	var s5 := access.state_name()

	_record("machine_access_full_cycle",
		s0 == "outside" and s1 == "in_zone" and interacted and s2 == "controlling"
			and s3 == "controlling" and exited and s5 == "outside",
		("outside(%s) -> in_zone(%s) -> interact=%s -> controlling(%s) "
			+ "-> still controlling while player moves away(%s) -> exit=%s(%s) -> outside(%s)")
			% [s0, s1, interacted, s2, s3, exited, s4, s5])


## Pure collision math: any load-person contact is a violation (lifting-safety
## doctrine, not an energy threshold); AABB overlap; floor/column contact.
func _test_load_body_collision_math() -> void:
	var danger: bool = LoadBodyScript.is_dangerous_impact(Vector3(0.1, 0.0, 0.0), 500.0)
	var push: Vector3 = LoadBodyScript.compute_push_velocity(Vector3(1.0, 0.0, 0.0))
	var overlap_yes: bool = LoadBodyScript.aabb_overlap(
		Vector3.ZERO, Vector3(1, 1, 1), Vector3(0.4, 0, 0), Vector3(1, 1, 1))
	var overlap_no: bool = LoadBodyScript.aabb_overlap(
		Vector3.ZERO, Vector3(1, 1, 1), Vector3(5, 0, 0), Vector3(1, 1, 1))
	var floor_hit: bool = LoadBodyScript.check_floor_contact(Vector3(0, 0.3, 0))
	var floor_clear: bool = LoadBodyScript.check_floor_contact(Vector3(0, 5.0, 0))
	var columns := [{"pos": Vector3(2, 4.35, 0.75), "size": Vector3(0.4, 8.7, 0.4)}]
	var col_hit: bool = LoadBodyScript.check_column_contact(Vector3(2, 4.0, 0.75), columns)
	var col_clear: bool = LoadBodyScript.check_column_contact(Vector3(20, 4.0, 0.75), columns)
	_record("load_body_collision_math",
		danger and push.length() > 0.0 and overlap_yes and not overlap_no
			and floor_hit and not floor_clear and col_hit and not col_clear,
		"danger=%s push_len=%.2f overlap(yes/no)=%s/%s floor(hit/clear)=%s/%s column(hit/clear)=%s/%s"
		% [danger, push.length(), overlap_yes, overlap_no, floor_hit, floor_clear, col_hit, col_clear])


## Bounce math: penetrating + moving into the surface -> corrected position
## sits exactly on it, velocity reflects with restitution/damping. Requested
## explicitly ("físicas de rebote... de impacto") after the previous version
## only detected and logged contact without any physical response.
func _test_load_body_impact_response() -> void:
	var restitution := 0.3
	var damping := 0.8

	var floor_hit: Dictionary = LoadBodyScript.resolve_floor_contact(
		Vector3(0.0, 0.2, 0.0), Vector3(1.0, -3.0, 0.5), restitution, damping)
	var floor_clear: Dictionary = LoadBodyScript.resolve_floor_contact(
		Vector3(0.0, 5.0, 0.0), Vector3(0.0, -3.0, 0.0), restitution, damping)
	var floor_leaving: Dictionary = LoadBodyScript.resolve_floor_contact(
		Vector3(0.0, 0.2, 0.0), Vector3(0.0, 1.0, 0.0), restitution, damping)
	var floor_ok: bool = floor_hit.hit and absf(floor_hit.center.y - 0.45) < 1e-6 \
		and absf(floor_hit.vel.y - 0.9) < 1e-6 and absf(floor_hit.vel.x - 0.8) < 1e-6 \
		and not floor_clear.hit and not floor_leaving.hit

	var columns := [{"pos": Vector3(10.0, 4.35, 0.75), "size": Vector3(0.4, 8.7, 0.4)}]
	var col_hit: Dictionary = LoadBodyScript.resolve_column_contact(
		Vector3(10.3, 4.0, 0.75), Vector3(-2.0, 0.0, 1.0), columns, restitution, damping)
	var col_clear: Dictionary = LoadBodyScript.resolve_column_contact(
		Vector3(30.0, 4.0, 0.75), Vector3(-2.0, 0.0, 1.0), columns, restitution, damping)
	var col_ok: bool = col_hit.hit and absf(col_hit.center.x - 10.8) < 1e-6 \
		and absf(col_hit.vel.x - 0.6) < 1e-6 and absf(col_hit.vel.z - 0.8) < 1e-6 \
		and not col_clear.hit

	_record("load_body_impact_response", floor_ok and col_ok,
		"floor: hit=%s center.y=%.3f vel=%s (clear=%s, leaving=%s) | column: hit=%s center.x=%.3f vel=%s (clear=%s)"
		% [floor_hit.hit, floor_hit.center.y, floor_hit.vel, floor_clear.hit, floor_leaving.hit,
			col_hit.hit, col_hit.center.x, col_hit.vel, col_clear.hit])


## Near-miss radius: larger than the exact contact box, per
## .claude/rules/simulation-physics.md ("separate physical collision volumes
## from safety/near-miss volumes").
func _test_load_safety_radius() -> void:
	var center := Vector3(10.0, 3.5, 9.0)
	var close_but_clear: bool = LoadBodyScript.is_within_safety_radius(
		center, Vector3(11.0, 3.5, 9.0), 2.0)
	var far_enough: bool = LoadBodyScript.is_within_safety_radius(
		center, Vector3(13.0, 3.5, 9.0), 2.0)
	_record("load_safety_radius_distinguishes_near_miss",
		close_but_clear and not far_enough,
		"1.0 m away (radius 2.0 m): near=%s; 3.0 m away: near=%s" % [close_but_clear, far_enough])


# --- multi-machine release ------------------------------------------------------

## Every catalogue entry must be internally consistent. A machine whose home
## pose sits outside its own limits, or whose chart is unsorted, produces a
## crane that silently cannot be driven — exactly the kind of bug that only
## shows up when a learner is already stuck in front of it.
func _test_catalog_integrity() -> void:
	var problems := PackedStringArray()
	for id in CatalogScript.MACHINES:
		var spec: Dictionary = CatalogScript.MACHINES[id]
		if String(spec.get("id", "")) != id:
			problems.append("%s: id field mismatch" % id)
		var axes: Dictionary = spec.get("axes", {})
		if axes.is_empty():
			problems.append("%s: no axes" % id)
		if not axes.has("hoist"):
			problems.append("%s: every machine needs a hoist axis" % id)
		for name in axes:
			var a: Dictionary = axes[name]
			for key in ["min", "max", "speed", "accel"]:
				if not a.has(key):
					problems.append("%s.%s: missing %s" % [id, name, key])
			if float(a.get("min", 0.0)) >= float(a.get("max", 0.0)):
				problems.append("%s.%s: min >= max" % [id, name])
			if float(a.get("speed", 0.0)) <= 0.0:
				problems.append("%s.%s: speed must be > 0" % [id, name])
		var home: Dictionary = spec.get("geometry", {}).get("home", {})
		for name in home:
			if not axes.has(name):
				problems.append("%s: home pose sets unknown axis '%s'" % [id, name])
				continue
			var v := float(home[name])
			if v < float(axes[name].min) - 0.001 or v > float(axes[name].max) + 0.001:
				problems.append("%s.%s: home %.2f outside limits" % [id, name, v])
		var chart: Array = spec.get("load_chart", [])
		if chart.is_empty():
			problems.append("%s: empty load chart" % id)
		else:
			for i in range(1, chart.size()):
				if float(chart[i][0]) <= float(chart[i - 1][0]):
					problems.append("%s: chart radii not ascending at row %d" % [id, i])
			if float(chart[0][1]) > float(spec.get("rated_capacity_kg", 0.0)) + 0.001:
				problems.append("%s: chart exceeds rated capacity" % id)
		if spec.get("needs_outriggers", false) and spec.get("outriggers", {}).is_empty():
			problems.append("%s: needs_outriggers but no outrigger footprint" % id)
		if String(spec.get("chart_source", "")) != CatalogScript.TRAINING_ENVELOPE:
			problems.append("%s: chart not labelled a training envelope" % id)
		if spec.get("environments", []).is_empty():
			problems.append("%s: not available in any environment" % id)
		if not CatalogScript.ORDER.has(id):
			problems.append("%s: missing from ORDER (would vanish from the menu)" % id)
	_record("catalog_integrity", problems.is_empty(),
		"%d machines checked; %s" % [CatalogScript.MACHINES.size(),
			"all consistent" if problems.is_empty() else ", ".join(problems)])


## Axes accelerate toward the commanded speed, clamp at their limits and stop
## dead there rather than accumulating phantom velocity.
func _test_rig_axis_limits_and_accel() -> void:
	var rig = MachineRigScript.new()
	rig.setup(CatalogScript.MACHINES["MC-OVH-05T"])
	var dt := 1.0 / 60.0

	# Unpowered means no motion at all, whatever the command.
	rig.step(dt, {"travel": 1.0})
	var idle_ok: bool = absf(rig.get_axis("travel") - 10.0) < 1e-9
	rig.powered = true

	# 48 m of travel at 0.8 m/s needs a full minute of simulated time; 4000
	# steps leaves headroom for the acceleration ramp at each end.
	for i in 4000:
		rig.step(dt, {"travel": 1.0})
	var at_limit := rig.get_axis("travel")
	var limit: float = float(CatalogScript.MACHINES["MC-OVH-05T"].axes.travel.max)
	var clamped: bool = absf(at_limit - limit) < 1e-6 and absf(rig.axis_vel.travel) < 1e-9

	rig.step(dt, {"travel": -1.0})
	var reverses: bool = rig.get_axis("travel") < limit

	rig.emergency_stop = true
	for i in 240:
		rig.step(dt, {"travel": -1.0})
	var stopped: bool = absf(rig.axis_vel.travel) < 1e-9

	_record("rig_axis_limits_and_accel",
		idle_ok and clamped and reverses and stopped,
		"unpowered_idle=%s clamped_at=%.3f (limit %.1f) reverses=%s estop_stops=%s"
		% [idle_ok, at_limit, limit, reverses, stopped])


## Each machine class resolves its rope head and working radius the way its
## geometry implies. These are the numbers the whole load-chart lesson rests
## on, so they are checked against hand-computed values.
func _test_rig_kinematics_per_class() -> void:
	var problems := PackedStringArray()

	var ovh = MachineRigScript.new()
	ovh.setup(CatalogScript.MACHINES["MC-OVH-05T"])
	ovh.axis.travel = 20.0
	ovh.axis.trolley = 5.0
	var h1: Vector3 = ovh.support_point()
	if h1.distance_to(Vector3(20.0, 9.0, 5.0)) > 1e-6:
		problems.append("overhead head %s != (20, 9, 5)" % h1)
	if absf(ovh.radius()) > 1e-9:
		problems.append("overhead radius should be 0, got %.3f" % ovh.radius())

	var twr = MachineRigScript.new()
	twr.setup(CatalogScript.MACHINES["MC-TWR-45M"])
	twr.axis.slew = 90.0
	twr.axis.trolley = 20.0
	var h2: Vector3 = twr.support_point()
	if h2.distance_to(Vector3(0.0, 42.0, 20.0)) > 1e-4:
		problems.append("tower head %s != (0, 42, 20)" % h2)
	if absf(twr.radius() - 20.0) > 1e-6:
		problems.append("tower radius %.3f != 20" % twr.radius())

	var mob = MachineRigScript.new()
	mob.setup(CatalogScript.MACHINES["MC-MOB-40T"])
	mob.axis.slew = 0.0
	mob.axis.luff = 60.0
	mob.axis.telescope = 20.0
	var expect_r: float = cos(deg_to_rad(60.0)) * 20.0
	var expect_y: float = 2.6 + sin(deg_to_rad(60.0)) * 20.0
	var h3: Vector3 = mob.support_point()
	if absf(mob.radius() - expect_r) > 1e-6:
		problems.append("mobile radius %.4f != %.4f" % [mob.radius(), expect_r])
	if absf(h3.x - expect_r) > 1e-4 or absf(h3.y - expect_y) > 1e-4:
		problems.append("mobile head %s wrong" % h3)

	# Railway: the slew centre travels with the machine, so the same world
	# target has a different radius from a different track position. That is
	# what makes "drive closer" a real answer to an overload (SC-504).
	var rail = MachineRigScript.new()
	rail.setup(CatalogScript.MACHINES["MC-RAIL-25T"])
	rail.axis.travel = 30.0
	rail.axis.slew = 0.0
	rail.axis.luff = 60.0
	var tip_a: Vector3 = rail.support_point()
	rail.axis.travel = 40.0
	var tip_b: Vector3 = rail.support_point()
	if absf((tip_b.x - tip_a.x) - 10.0) > 1e-6:
		problems.append("railway travel did not shift the boom tip by 10 m (got %.4f)"
			% (tip_b.x - tip_a.x))
	if absf(rail.radius() - cos(deg_to_rad(60.0)) * 22.0) > 1e-6:
		problems.append("railway radius %.4f wrong for a fixed 22 m boom" % rail.radius())

	_record("rig_kinematics_per_class", problems.is_empty(),
		"overhead/tower/mobile/railway heads and radii; %s"
		% ("all match hand-computed values" if problems.is_empty() else ", ".join(problems)))


## The set-up interlock: no slew, luff, telescope or travel until the outriggers
## are down, but hoist stays live so the operator can take up slack.
func _test_rig_outrigger_interlock() -> void:
	var rig = MachineRigScript.new()
	rig.setup(CatalogScript.MACHINES["MC-MOB-40T"])
	rig.powered = true
	var dt := 1.0 / 60.0
	var slew0 := rig.get_axis("slew")
	var hoist0 := rig.get_axis("hoist")

	for i in 60:
		rig.step(dt, {"slew": 1.0, "hoist": 1.0})
	var slew_locked: bool = absf(rig.get_axis("slew") - slew0) < 1e-9
	var hoist_free: bool = rig.get_axis("hoist") > hoist0 + 0.01
	var stowed: bool = not rig.outriggers_ready()

	for i in 300:
		rig.step(dt, {"outriggers": 1.0})
	var deployed: bool = rig.outriggers_ready()
	for i in 60:
		rig.step(dt, {"slew": 1.0})
	var slew_free: bool = rig.get_axis("slew") > slew0 + 0.01

	var half_out: Vector2 = rig.support_half_extents()
	rig.outriggers = 0.0
	var half_in: Vector2 = rig.support_half_extents()

	_record("rig_outrigger_interlock",
		stowed and slew_locked and hoist_free and deployed and slew_free
			and half_out.x > half_in.x,
		"stowed=%s slew_locked=%s hoist_free=%s deployed=%s slew_free=%s footprint %.2f->%.2f m"
		% [stowed, slew_locked, hoist_free, deployed, slew_free, half_in.x, half_out.x])


## Chart interpolation, the minimum-radius plateau, and the honest answer past
## the end of the chart: no rating, not an extrapolated guess.
func _test_load_chart_lookup() -> void:
	var chart := [[3.0, 40000.0], [6.0, 21000.0], [12.0, 8000.0]]
	var below: float = LoadChartScript.capacity_at(chart, 1.0)
	var exact: float = LoadChartScript.capacity_at(chart, 6.0)
	var mid: float = LoadChartScript.capacity_at(chart, 9.0)
	var beyond: float = LoadChartScript.capacity_at(chart, 20.0)
	var flat: float = LoadChartScript.capacity_at([[0.0, 5000.0]], 999.0)

	var off: bool = LoadChartScript.is_out_of_chart(chart, 20.0)
	var on: bool = LoadChartScript.is_out_of_chart(chart, 11.0)

	var st_safe: int = LoadChartScript.status_for(chart, 6.0, 10000.0)
	var st_warn: int = LoadChartScript.status_for(chart, 6.0, 19500.0)
	var st_over: int = LoadChartScript.status_for(chart, 6.0, 22000.0)
	var st_off: int = LoadChartScript.status_for(chart, 25.0, 100.0)

	var ok: bool = absf(below - 40000.0) < 1e-6 and absf(exact - 21000.0) < 1e-6 \
		and absf(mid - 14500.0) < 1e-6 and absf(beyond) < 1e-9 \
		and absf(flat - 5000.0) < 1e-6 and off and not on \
		and st_safe == LoadChartScript.Status.SAFE \
		and st_warn == LoadChartScript.Status.WARNING \
		and st_over == LoadChartScript.Status.OVERLOAD \
		and st_off == LoadChartScript.Status.OUT_OF_CHART
	_record("load_chart_lookup", ok,
		"plateau=%.0f exact=%.0f interp@9m=%.0f (expect 14500) beyond=%.0f flat=%.0f"
		% [below, exact, mid, beyond, flat])


## The planning question an operator actually has: how far out can I take this?
func _test_load_chart_planning() -> void:
	var chart := [[3.0, 40000.0], [6.0, 21000.0], [12.0, 8000.0]]
	var r_mid: float = LoadChartScript.max_radius_for(chart, 14500.0)
	var r_heavy: float = LoadChartScript.max_radius_for(chart, 50000.0)
	var r_light: float = LoadChartScript.max_radius_for(chart, 100.0)
	var moment: float = LoadChartScript.load_moment_tm(12.0, 2500.0)
	var ok: bool = absf(r_mid - 9.0) < 1e-6 and absf(r_heavy) < 1e-9 \
		and absf(r_light - 12.0) < 1e-6 and absf(moment - 30.0) < 1e-6
	_record("load_chart_planning", ok,
		"max radius: 14.5 t -> %.2f m (expect 9.00), 50 t -> %.2f m (expect 0), 0.1 t -> %.2f m; 2.5 t at 12 m = %.1f tm"
		% [r_mid, r_heavy, r_light, moment])


## Sling angle is the classic exam trap: closing the angle to horizontal from
## 90 to 30 degrees doubles the tension in every leg.
func _test_rigging_math() -> void:
	var f90: float = RiggingScript.angle_factor(90.0)
	var f60: float = RiggingScript.angle_factor(60.0)
	var f45: float = RiggingScript.angle_factor(45.0)
	var f30: float = RiggingScript.angle_factor(30.0)

	var t90: float = RiggingScript.leg_tension_n(1000.0, 2, 90.0) / RiggingScript.G
	var t30: float = RiggingScript.leg_tension_n(1000.0, 2, 30.0) / RiggingScript.G
	# A 4-leg sling is rated on two legs, not four — the conservative convention.
	var t4: float = RiggingScript.leg_tension_n(1000.0, 4, 90.0) / RiggingScript.G

	var gross: float = RiggingScript.gross_load_kg(1000.0, 250.0)
	var bad_angle: bool = not RiggingScript.is_angle_acceptable(25.0)
	var geo: float = RiggingScript.angle_from_geometry_deg(2.0, 1.0)

	var ok: bool = absf(f90 - 1.0) < 1e-6 and absf(f60 - 1.1547) < 1e-4 \
		and absf(f45 - 1.41421) < 1e-4 and absf(f30 - 2.0) < 1e-6 \
		and absf(t90 - 500.0) < 1e-3 and absf(t30 - 1000.0) < 1e-3 \
		and absf(t4 - 500.0) < 1e-3 and absf(gross - 1250.0) < 1e-9 \
		and bad_angle and absf(geo - 60.0) < 1e-4
	_record("rigging_math", ok,
		"factors 90/60/45/30 = %.3f/%.3f/%.3f/%.3f; 1 t on 2 legs: %.0f kg at 90deg, %.0f kg at 30deg; 4-leg rated on 2 = %.0f kg; 25deg rejected=%s"
		% [f90, f60, f45, f30, t90, t30, t4, bad_angle])


## Tipping geometry: the support rectangle is narrowest over the middle of a
## side and widest over a corner, and a load still inside the polygon cannot
## tip the machine at all.
func _test_stability_model() -> void:
	var half := Vector2(3.6, 3.4)
	# Resisting arm: over the front it is half_x, over a side it is half_z.
	var d_front: float = StabilityScript.tipping_distance(half, 0.0)
	var d_side: float = StabilityScript.tipping_distance(half, PI / 2.0)

	# The behaviour that matters for set-up: at the SAME radius, a corner is
	# markedly more stable than the middle of a side, and the side is the worst
	# case on a footprint that is narrower across than along.
	var f_front: float = StabilityScript.stability_factor(40000.0, 5000.0, 12.0, half, 0.0)
	var f_side: float = StabilityScript.stability_factor(40000.0, 5000.0, 12.0, half, PI / 2.0)
	var f_corner: float = StabilityScript.stability_factor(40000.0, 5000.0, 12.0, half, PI / 4.0)

	var inside: float = StabilityScript.stability_factor(40000.0, 5000.0, 2.0, half, 0.0)
	var heavier: float = StabilityScript.stability_factor(40000.0, 9000.0, 12.0, half, 0.0)

	# The planning answer must agree with the alarm: at exactly max_stable_radius
	# the factor must come out at the required threshold.
	var r_max: float = StabilityScript.max_stable_radius(40000.0, 5000.0, half, PI / 2.0,
		StabilityScript.FACTOR_SAFE)
	var f_at_max: float = StabilityScript.stability_factor(40000.0, 5000.0, r_max, half, PI / 2.0)

	var side_name: String = StabilityScript.tipping_side(PI / 2.0)
	var levels_ok: bool = StabilityScript.level_for(2.0) == StabilityScript.Level.STABLE \
		and StabilityScript.level_for(1.30) == StabilityScript.Level.CAUTION \
		and StabilityScript.level_for(1.10) == StabilityScript.Level.CRITICAL \
		and StabilityScript.level_for(0.80) == StabilityScript.Level.TIPPING

	# Vector2 components are 32-bit, so 3.6 round-trips as ~3.59999990. The
	# tolerance has to respect the type's precision, not float64's.
	var ok: bool = absf(d_front - 3.6) < 1e-5 and absf(d_side - 3.4) < 1e-5 \
		and f_corner > f_front and f_front > f_side \
		and is_inf(inside) and heavier < f_front \
		and absf(f_at_max - StabilityScript.FACTOR_SAFE) < 1e-4 \
		and side_name == "right" and levels_ok
	_record("stability_model", ok,
		"resisting arm front/side = %.2f/%.2f m; factor at 12 m corner/front/side = %.2f/%.2f/%.2f; inside=%s heavier=%.2f; max_stable_radius %.2f m -> factor %.3f (target %.2f); bands_ok=%s"
		% [d_front, d_side, f_corner, f_front, f_side, inside, heavier,
			r_max, f_at_max, StabilityScript.FACTOR_SAFE, levels_ok])


## The guidance state machine replaced the old fixed tutorial. It is a pure
## function of state, so it must recover correctly no matter what order the
## learner does things in — including undoing a step.
func _test_guidance_state_machine() -> void:
	var cases := [
		[{"controlling": false, "in_zone": false}, "approach"],
		[{"controlling": false, "in_zone": true}, "take_controls"],
		[{"controlling": true, "needs_outriggers": true, "outriggers_ready": false}, "outriggers"],
		[{"controlling": true, "needs_outriggers": true, "outriggers_ready": true,
			"powered": false}, "inspect"],
		[{"controlling": true, "powered": true, "phase": "not_started",
			"hook_low": false}, "lower_hook"],
		[{"controlling": true, "powered": true, "phase": "not_started",
			"hook_low": true}, "attach"],
		[{"controlling": true, "powered": true, "phase": "carrying",
			"near_target": false}, "travel"],
		[{"controlling": true, "powered": true, "phase": "carrying",
			"near_target": true}, "deliver"],
		[{"controlling": true, "powered": true, "phase": "delivered"}, "release"],
		# Regression: dropping the controls mid-job must go back to "approach",
		# not leave the learner staring at a stale in-machine instruction.
		[{"controlling": false, "in_zone": false, "powered": true,
			"phase": "carrying"}, "approach"],
	]
	var all_ok := true
	var detail := ""
	for c in cases:
		var got: String = GuidanceScript.current_step(c[0])
		if got != c[1]:
			all_ok = false
			detail += "expected=%s got=%s; " % [c[1], got]
	var prev := -1.0
	for step in GuidanceScript.STEPS:
		var p := float(GuidanceScript.step_index(step))
		if p <= prev:
			all_ok = false
			detail += "step order not monotonic at %s; " % step
		prev = p
	_record("guidance_state_machine", all_ok,
		detail if not all_ok else "%d/%d state cases correct, step order monotonic"
			% [cases.size(), cases.size()])
