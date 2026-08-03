extends Node
## Scene selftest — the tier that module_tests.gd cannot cover.
##
## module_tests.gd runs under `--script`, where autoloads do not exist, so it
## can only reach pure logic. Everything that needs a real tree — the session
## building a world, a machine visual existing, input actually reaching the
## rig, the catalogues and the scenario database agreeing with each other — is
## verified here, inside a live session.
##
## Coverage strategy: rather than testing one scenario deeply and hoping the
## rest work, this driver REBUILDS THE SESSION for every scenario in the
## database in turn. That is the check that matters for a multi-machine
## release — it proves all seven machines construct, in all five sites, under
## every weather preset the content uses, and that each job's zones are
## actually reachable by the machine assigned to it.
##
## State is STATIC because reloading the scene destroys this node: the driver
## is re-attached by session.gd on every rebuild and picks up where it left off.
##
## Run:  START_SIMULATOR.bat --headless -- --selftest --out=<abs dir>

const HEADER := "[SELFTEST]"

static var results: Array = []
static var queue: Array = []
## Machine ids whose full interaction path has already been exercised. Deep
## checks run ONCE PER MACHINE, not once per run: a control binding that works
## on the overhead crane says nothing about whether the mobile crane's luff
## key reaches its axis, and that is exactly the class of bug this release is
## meant to eliminate.
static var deep_done: Dictionary = {}
static var static_checks_done := false

var session: Node3D
var _phase := "boot"
var _ticks := 0
var _current := ""


func _ready() -> void:
	session = get_parent()
	_current = String(session.scenario.get("id", ""))

	if not static_checks_done:
		static_checks_done = true
		queue = ScenarioDB.all_ids()
		_record("scenario_db_loaded",
			ScenarioDB.load_errors.is_empty() and queue.size() > 0,
			"%d scenarios, %d load errors%s" % [queue.size(), ScenarioDB.load_errors.size(),
				"" if ScenarioDB.load_errors.is_empty() else ": " + str(ScenarioDB.load_errors)])
		_check_catalog_coverage()
	queue.erase(_current)


func _record(id: String, ok: bool, detail: String) -> void:
	results.append({"id": id, "ok": ok, "detail": detail})
	print("%s %s %s -- %s" % [HEADER, "[OK]  " if ok else "[FAIL]", id, detail])


# --- static cross-checks that still need the autoloads ---------------------------

## Every machine must have at least one environment that exists, every declared
## axis must have a control binding, every environment's builder must load, and
## every environment must be reachable by at least one machine — otherwise a
## site is dead content or an axis is one the player physically cannot move.
func _check_catalog_coverage() -> void:
	var problems := PackedStringArray()
	var covered := {}
	for mid in MachineCatalog.all_ids():
		var spec := MachineCatalog.get_spec(mid)
		var pairs := ControlScheme.pairs_for(spec)
		if pairs.is_empty():
			problems.append("%s: control scheme yields no axes" % mid)
		var driven := {}
		for p in pairs:
			driven[String(p.axis)] = true
		for axis_name in spec.get("axes", {}):
			if not driven.has(axis_name):
				problems.append("%s: axis '%s' has no control binding" % [mid, axis_name])
		for eid in spec.environments:
			if not EnvironmentCatalog.has_env(eid):
				problems.append("%s: unknown environment '%s'" % [mid, eid])
				continue
			covered[eid] = true
			if load(EnvironmentCatalog.builder_path(eid)) == null:
				problems.append("%s: builder for '%s' does not load" % [mid, eid])
	for eid in EnvironmentCatalog.all_ids():
		if not covered.has(eid):
			problems.append("%s: no machine can work here" % eid)
	_record("catalog_environment_coverage", problems.is_empty(),
		"%d machines x %d sites; %s" % [MachineCatalog.all_ids().size(),
			EnvironmentCatalog.all_ids().size(),
			"all wired" if problems.is_empty() else ", ".join(problems)])

	var weather_problems := PackedStringArray()
	for sid in ScenarioDB.all_ids():
		var w := String(ScenarioDB.get_scenario(sid).get("weather", "clear"))
		if not Weather.has_weather(w):
			weather_problems.append("%s: unknown weather '%s'" % [sid, w])
	_record("weather_presets_exist", weather_problems.is_empty(),
		"%d presets; %s" % [Weather.ORDER.size(),
			"all scenario weather valid" if weather_problems.is_empty()
			else ", ".join(weather_problems)])


# --- per-session checks ------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_ticks += 1
	match _phase:
		"boot":
			if _ticks > 4:
				_check_construction(_current)
				_phase = "deep" if not deep_done.has(String(session.spec.id)) else "next"
				_ticks = 0
		"deep":
			_run_deep_checks()
		"next":
			_advance()


## Construction check, run for EVERY scenario: world, machine, HUD and physics
## all exist and are self-consistent, and the job's zones sit inside the
## machine's actual working envelope.
func _check_construction(sid: String) -> void:
	var s: Node3D = session
	var spec: Dictionary = s.spec
	var problems := PackedStringArray()

	if s.world == null:
		problems.append("no world")
	elif s.world.obstacles.is_empty():
		problems.append("site registered no load obstacles")
	if s.visual == null:
		problems.append("no machine visual")
	if s.hud == null:
		problems.append("no HUD")
	if s.rig == null or s.sim == null:
		problems.append("no rig/sim")

	if s.rig != null:
		var head: Vector3 = s.rig.support_point()
		if not head.is_finite():
			problems.append("rope head non-finite")
		elif head.y <= 0.5:
			problems.append("rope head at or below ground (%.2f m)" % head.y)
	if s.sim != null and not s.sim.load_pos.is_finite():
		problems.append("load position non-finite")

	# Reachability, re-run against the LIVE rig so content and code can never
	# drift apart the way a generator-only check would allow.
	for key in ["pickup", "dropoff"]:
		var zone: Dictionary = s.scenario.get(key, {})
		if not zone.is_empty() and not _zone_reachable(spec, zone):
			problems.append("%s zone (%.1f, %.1f) outside the machine's envelope"
				% [key, zone.x, zone.z])

	_record("build_%s" % sid, problems.is_empty(),
		"%s in %s (%s); %s" % [MachineCatalog.display_name(spec),
			EnvironmentCatalog.display_name(String(s.scenario.environment)),
			String(s.scenario.get("weather", "clear")),
			"built clean" if problems.is_empty() else ", ".join(problems)])


## Can this machine put its hook over that XZ point at all?
func _zone_reachable(spec: Dictionary, zone: Dictionary) -> bool:
	var axes: Dictionary = spec.get("axes", {})
	var x := float(zone.x)
	var z := float(zone.z)
	match String(spec["class"]):
		MachineCatalog.CLASS_OVERHEAD, MachineCatalog.CLASS_GANTRY:
			return x >= float(axes.travel.min) and x <= float(axes.travel.max) \
				and z >= float(axes.trolley.min) and z <= float(axes.trolley.max)
		MachineCatalog.CLASS_TOWER:
			var r := Vector2(x, z).length()
			return r >= float(axes.trolley.min) - 0.01 and r <= float(axes.trolley.max) + 0.01
		_:
			var g: Dictionary = spec.get("geometry", {})
			var max_len: float = float(axes.telescope.max) if axes.has("telescope") \
				else float(g.get("boom_length", 20.0))
			var min_len: float = float(axes.telescope.min) if axes.has("telescope") \
				else float(g.get("boom_length", 20.0))
			var hi: float = cos(deg_to_rad(maxf(0.0, float(axes.luff.min)))) * max_len
			var lo: float = cos(deg_to_rad(float(axes.luff.max))) * min_len
			# A rail-mounted machine drives along X, so only the perpendicular
			# offset has to fit inside maximum reach.
			if axes.has("travel"):
				return absf(z) <= hi + 0.01
			var r2 := Vector2(x, z).length()
			return r2 <= hi + 0.01 and r2 >= lo - 0.01


## The full interaction path, run once: take the controls, set the machine up,
## drive every axis, cycle the cameras, reset. This is the "can a player
## actually operate it" test, and it is driven through the REAL input map so a
## broken binding fails here rather than in front of a learner.
func _run_deep_checks() -> void:
	var s: Node3D = session
	var spec: Dictionary = s.spec

	# 1. Stand at the control position and take the controls.
	s.player.global_position = s.world.control_position + Vector3(0.3, 0.2, 0.0)
	s.access.update(0.0, s.player.global_position, s.world.control_position,
		AppSettings.ACCESS_RADIUS_M)
	var in_zone: bool = s.access.state == s.access.State.IN_ZONE
	_press("interact")
	_record("take_controls", in_zone and s.access.is_controlling(),
		"in_zone=%s -> controlling=%s at %s" % [in_zone, s.access.is_controlling(),
			s.world.control_position])

	# 2. Guidance must never be blank — a player stuck on a step with no text
	#    on screen is precisely the failure this release exists to fix.
	var blank := 0
	for i in 3:
		if String(s._hud_context().get("guidance_text", "")).strip_edges() == "":
			blank += 1
	_record("guidance_never_blank", blank == 0,
		"guidance text present on every sampled frame (%d blanks)" % blank)

	# 3. Outriggers and the motion interlock.
	if bool(spec.get("needs_outriggers", false)):
		var locked_axis := "slew" if s.rig.has_axis("slew") else "travel"
		var before: float = s.rig.get_axis(locked_axis)
		s.rig.powered = true
		s.rig.outriggers = 0.0
		for i in 30:
			s.rig.step(AppSettings.DT, {locked_axis: 1.0})
		var locked: bool = absf(s.rig.get_axis(locked_axis) - before) < 1e-6
		for i in 400:
			s.rig.step(AppSettings.DT, {"outriggers": 1.0})
		_record("outrigger_interlock_live", locked and s.rig.outriggers_ready(),
			"%s locked while stowed=%s, deployed=%s" % [locked_axis, locked,
				s.rig.outriggers_ready()])
	else:
		_record("outrigger_interlock_live", true, "machine has no outriggers (n/a)")

	# 4. Pre-use checks power the machine up; it is dead before them.
	s.rig.powered = false
	for i in s.checks.size():
		s.checks[i] = false
	var dead: bool = not s.rig.powered
	for i in s.checks.size():
		_press("inspect_%d" % (i + 1))
	_record("pre_use_checks_power_machine", dead and s.rig.powered,
		"%d checks -> powered=%s" % [s.checks.size(), s.rig.powered])

	# 5. Every control pair actually moves its axis, through the real input map.
	var axis_problems := PackedStringArray()
	s.rig.powered = true
	s.rig.outriggers = 1.0
	var pairs := ControlScheme.pairs_for(spec)
	for pair in pairs:
		var axis_name := String(pair.axis)
		var actions: Array = pair.actions
		var start: float = s.rig.get_axis(axis_name)
		Input.action_press(actions[1])
		for i in 60:
			s.rig.step(AppSettings.DT, ControlScheme.read_commands(spec))
		Input.action_release(actions[1])
		var after_pos: float = s.rig.get_axis(axis_name)
		Input.action_press(actions[0])
		for i in 120:
			s.rig.step(AppSettings.DT, ControlScheme.read_commands(spec))
		Input.action_release(actions[0])
		var after_neg: float = s.rig.get_axis(axis_name)
		if absf(after_pos - start) < 1e-4:
			axis_problems.append("%s did not move on %s (%s)"
				% [axis_name, pair.keys[0], actions[1]])
		if absf(after_neg - after_pos) < 1e-4:
			axis_problems.append("%s did not move on %s (%s)"
				% [axis_name, pair.keys[1], actions[0]])
	_record("every_control_moves_its_axis", axis_problems.is_empty(),
		"%d control pairs on %s; %s" % [pairs.size(), MachineCatalog.display_name(spec),
			"all responded" if axis_problems.is_empty() else ", ".join(axis_problems)])

	# 6. ALL STOP brakes everything.
	s.rig.emergency_stop = true
	for i in 200:
		s.rig.step(AppSettings.DT, {"hoist": 1.0, "travel": 1.0, "slew": 1.0,
			"luff": 1.0, "telescope": 1.0, "trolley": 1.0})
	var all_stopped := true
	for name in s.rig.axis_vel:
		if absf(float(s.rig.axis_vel[name])) > 1e-6:
			all_stopped = false
	s.rig.emergency_stop = false
	_record("all_stop_brakes_every_axis", all_stopped,
		"velocities after ALL STOP: %s" % s.rig.axis_vel)

	# 7. Cameras: every allowed mode produces a finite transform.
	var seen := []
	var cam_ok := true
	for i in s.cam.allowed_modes.size():
		s.cam.cycle_mode()
		s.cam.update(0.016)
		if not s.cam.camera.global_transform.origin.is_finite():
			cam_ok = false
		seen.append(s.cam.active_view_name())
	s.cam.go_home()
	_record("camera_modes_valid", cam_ok and seen.size() == s.cam.allowed_modes.size(),
		"modes cycled: %s" % str(seen))

	# 8. LMI and stability produce sane numbers.
	s._update_limits()
	_record("limits_computed",
		is_finite(s.lmi_util) and s.lmi_util >= 0.0 and s.stability.has("level"),
		"radius=%.2f m capacity=%.0f kg util=%.0f%% stability=%s"
		% [s.rig.radius(), s.lmi_capacity, s.lmi_util * 100.0,
			s.stability.get("level_key", "?")])

	# 9. Reset returns the machine home WITHOUT moving the operator.
	var player_before: Vector3 = s.player.global_position
	var first_axis: String = s.rig.axis.keys()[0]
	s.rig.axis[first_axis] = float(spec.axes[first_axis].min)
	s.reset_all()
	var home: Dictionary = spec.get("geometry", {}).get("home", {})
	var back_home: bool = absf(s.rig.get_axis(first_axis)
		- float(home.get(first_axis, s.rig.get_axis(first_axis)))) < 1e-4
	var player_moved: float = player_before.distance_to(s.player.global_position)
	_record("reset_machine_not_operator",
		back_home and player_moved < 0.01 and not s.rig.powered,
		"axis '%s' home=%s, operator moved %.4f m, powered=%s"
		% [first_axis, back_home, player_moved, s.rig.powered])

	# 10. Physics stays finite over a driven stress burst.
	var bad := 0
	for i in 600:
		s.sim.step(s.rig.support_point()
			+ Vector3(sin(i * 0.1) * 2.0, 0.0, cos(i * 0.07) * 2.0),
			Vector3(6.0, 0.0, 3.0))
		if not (s.sim.load_pos.is_finite() and s.sim.load_vel.is_finite()):
			bad += 1
	_record("session_physics_finite", bad == 0,
		"%d non-finite states over 600 driven steps" % bad)

	deep_done[String(spec.id)] = true
	_phase = "next"
	_ticks = 0


## Presses an action for one frame through the real input map, exactly as a key
## would — so a wrong binding fails the test rather than being bypassed.
func _press(action: String) -> void:
	Input.action_press(action)
	session._handle_discrete()
	Input.action_release(action)
	session._handle_discrete()


# --- walk the rest of the library ---------------------------------------------------

func _advance() -> void:
	if queue.is_empty():
		_finish()
		return
	GameState.select_scenario(ScenarioDB.get_scenario(String(queue.pop_front())))
	_phase = "done"
	get_tree().reload_current_scene()


func _finish() -> void:
	var all_ok := true
	for r in results:
		if not r.ok:
			all_ok = false
	var summary := {
		"suite": "scene_selftest",
		"godot": Engine.get_version_info().string,
		"machines": MachineCatalog.all_ids().size(),
		"environments": EnvironmentCatalog.all_ids().size(),
		"scenarios": ScenarioDB.all_ids().size(),
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
		var f := FileAccess.open(out_dir.path_join("SELFTEST_RESULTS.json"), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(summary, "  "))
			f.close()
	print("%s %d/%d passed -> %s" % [HEADER, summary.passed, summary.total,
		"PASS" if all_ok else "FAIL"])
	get_tree().quit(0 if all_ok else 1)
