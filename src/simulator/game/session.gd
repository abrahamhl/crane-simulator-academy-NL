extends Node3D
## Session — the playable scene, generic over machine, site, weather and job.
##
## Reads GameState's selection ONCE at _ready and builds everything from data:
## the environment builder named by the site, the machine visual and rig named
## by the machine spec, the load and objective named by the scenario. Nothing
## in this file knows which crane it is driving, which is why adding the
## seventh machine did not require touching it.
##
## Tick order each physics frame, and the reason for it:
##   1. access + discrete actions   — so a control taken this frame acts now
##   2. rig.step                    — machine kinematics move the rope head
##   3. wind, then cable substeps   — load follows the head it can now see
##   4. impact resolution           — external correction on the trusted
##                                    free-swing integrator (DEC-009)
##   5. hazards / LMI / stability   — read the resolved state, never predict it
##   6. scenario runner             — scores what actually happened
## Reordering these silently changes the physics; they are not interchangeable.

const CableLoadSimScript := preload("res://core/cable_load_sim.gd")
const WindModelScript := preload("res://core/wind_model.gd")
const TelemetryScript := preload("res://core/telemetry.gd")
const PlayerControllerScript := preload("res://core/player_controller.gd")
const CameraDirectorScript := preload("res://core/camera_director.gd")
const MachineAccessScript := preload("res://core/machine_access.gd")
const MachineRigScript := preload("res://core/machine_rig.gd")
const MachineVisualScript := preload("res://machines/machine_visual.gd")
const LoadBodyScript := preload("res://core/load_body.gd")
const ScenarioRunnerScript := preload("res://core/scenario_runner.gd")
const GuidanceScript := preload("res://core/guidance.gd")
const LoadChartScript := preload("res://core/load_chart.gd")
const StabilityScript := preload("res://core/stability_model.gd")
const RiggingScript := preload("res://core/rigging.gd")
const HudScript := preload("res://ui/hud.gd")
const PauseMenuScript := preload("res://ui/pause_menu.gd")
const ResultsScript := preload("res://ui/results_screen.gd")

const DT := AppSettings.DT
const SUBSTEPS := AppSettings.CABLE_SUBSTEPS

signal session_finished(result: Dictionary)

# --- selection (frozen at _ready) --------------------------------------------
var spec: Dictionary = {}
var env_spec: Dictionary = {}
var scenario: Dictionary = {}
var weather_id := "clear"
var diff: Dictionary = {}

# --- simulation --------------------------------------------------------------
var rig: RefCounted
var sim: RefCounted
var wind_model: RefCounted
var telemetry: RefCounted
var runner: RefCounted

var world: Node3D
var visual: Node3D
var player: CharacterBody3D
var cam: Node3D
var access: RefCounted
var load_body: Area3D
var load_mesh: MeshInstance3D
var safety_ring: MeshInstance3D
var hud: CanvasLayer
var pause_menu: CanvasLayer
var results: CanvasLayer
var precip: GPUParticles3D

var checks: Array = []
var wind_enabled := true
var applied_wind := Vector3.ZERO
var elapsed_ticks := 0
var halted := false
var finished := false
var load_size := Vector3(1.2, 0.9, 1.2)
var gross_kg := 0.0
var rigging_plan: Dictionary = {}

# LMI / stability, recomputed each tick and read by the HUD.
var lmi_status: int = 0
var lmi_util := 0.0
var lmi_capacity := 0.0
var stability: Dictionary = {}
var over_wind := false

var _prev_action := {}
var _prev_floor := false
var _prev_obstacle := false
var _prev_near := false
var _tick_collisions := 0
var _tick_violations := 0
var _tick_near := 0
var _tick_hazard := ""
var _outrigger_cmd := 0.0
var _signal_text := ""
var _signal_timer := 0.0

## Set by tests/demo_pilot.gd when `--demo` is passed. When present it supplies
## the axis commands instead of the input map — the session still owns the tick
## order and is still the only place the simulation advances.
var demo: Node = null


func _ready() -> void:
	_freeze_selection()
	_build_world()
	_build_actors()
	_build_ui()
	reset_all()

	if not _is_selftest():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		var driver: GDScript = load("res://tests/selftest_driver.gd")
		if driver != null:
			add_child(driver.new())

	# `-- --demo` hands the machine to a proportional controller that completes
	# the lift on its own. Used to record footage and as the attract loop on
	# the web build; it drives through the same command path a player uses.
	if OS.get_cmdline_user_args().has("--demo"):
		var pilot: GDScript = load("res://tests/demo_pilot.gd")
		if pilot != null:
			add_child(pilot.new())
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_setup_screenshot()


## `-- --screenshot=<dir>` renders a few frames, captures the viewport and
## quits. Visual output was previously verified only as "the log had no
## errors", which cannot catch a black screen, a missing material or a camera
## pointing at nothing. This makes the picture itself an inspectable artefact.
func _setup_screenshot() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--screenshot="):
			continue
		var dir := arg.trim_prefix("--screenshot=")
		var view := String(_cmdline_value("--view", ""))
		var frames := int(_cmdline_value("--frames", "90"))
		# Deferred so the first frames have run: procedural textures are
		# generated on demand and lighting needs a frame or two to settle.
		_capture_after(dir, view, frames)
		return


func _cmdline_value(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.trim_prefix(key + "=")
	return fallback


func _capture_after(dir: String, view: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	if view != "":
		# Park the camera on a named view so a screenshot run is reproducible.
		match view:
			"orbit": cam.mode = cam.Mode.ORBIT
			"hook": cam.mode = cam.Mode.HOOK
			"topdown": cam.mode = cam.Mode.TOPDOWN
			"boom": cam.mode = cam.Mode.BOOM
			_: cam.mode = cam.Mode.HOME
		cam.update(0.016)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var name := "%s_%s_%s.png" % [String(scenario.get("id", "free")),
		GameState.machine_id, view if view != "" else "home"]
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name)
	var err := img.save_png(path)
	print("[SCREENSHOT] %s -> %s" % ["ok" if err == OK else "FAILED", path])
	get_tree().quit(0 if err == OK else 1)


func _is_selftest() -> bool:
	return OS.get_cmdline_user_args().has("--selftest")


## Everything the session runs on is captured here and never re-read, so a
## menu change mid-session cannot half-apply.
func _freeze_selection() -> void:
	# `-- --scenario=SC-404` jumps straight into one job. Exists for QA and for
	# instructors demonstrating a specific lift, and it goes through
	# GameState.select_scenario so the machine, site and weather follow.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			var sid := arg.trim_prefix("--scenario=")
			if ScenarioDB.has_scenario(sid):
				GameState.select_scenario(ScenarioDB.get_scenario(sid))
			else:
				push_error("Session: unknown --scenario=%s" % sid)

	spec = MachineCatalog.get_spec(GameState.machine_id)
	env_spec = EnvironmentCatalog.get_env(GameState.environment_id)
	weather_id = GameState.weather_id
	diff = GameState.difficulty_config()
	scenario = ScenarioDB.get_scenario(GameState.scenario_id)

	if GameState.free_practice or scenario.is_empty():
		scenario = _synthetic_scenario()

	gross_kg = ScenarioDB.gross_kg(scenario)
	var ls = scenario.get("load_size", [1.2, 0.9, 1.2])
	load_size = Vector3(float(ls[0]), float(ls[1]), float(ls[2]))

	var r: Dictionary = scenario.get("rigging", {})
	rigging_plan = RiggingScript.plan(
		float(scenario.get("payload_kg", 500.0)),
		float(scenario.get("below_hook_kg", 0.0)),
		int(r.get("legs", 2)),
		float(r.get("angle_deg", 60.0)),
		float(r.get("wll_per_leg_kg", 2000.0)))

	checks.clear()
	var n := 4 if bool(spec.get("needs_outriggers", false)) else 3
	for i in n:
		checks.append(false)


## Free practice still needs somewhere to pick up and put down, or the whole
## HUD has nothing to show. Generated from the machine's own reach so it is
## always achievable on whatever machine was chosen.
func _synthetic_scenario() -> Dictionary:
	var reach := 12.0
	var a: Dictionary = spec.get("axes", {})
	if a.has("trolley"):
		reach = (float(a.trolley.min) + float(a.trolley.max)) * 0.5
	elif a.has("telescope"):
		reach = float(a.telescope.min) * 0.8
	var cls := String(spec.get("class", ""))
	var pick := Vector2(reach, 0.0)
	var drop := Vector2(reach * 0.75, 6.0)
	if cls == MachineCatalog.CLASS_OVERHEAD or cls == MachineCatalog.CLASS_GANTRY:
		pick = Vector2(float(a.travel.min) + 8.0, reach)
		drop = Vector2(float(a.travel.min) + 22.0, reach * 0.6)
	return {
		"id": "",
		"title": {"en": "Free practice", "es": "Práctica libre", "nl": "Vrij oefenen"},
		"briefing": {"en": "No objective and no score. Move the machine, feel the load, use the whole envelope.",
			"es": "Sin objetivo ni puntuación. Mueve la máquina, siente la carga, usa toda la envolvente.",
			"nl": "Geen doel, geen score. Beweeg de machine en voel de last."},
		"machine": GameState.machine_id,
		"environment": GameState.environment_id,
		"payload_kg": 1000.0,
		"below_hook_kg": 60.0,
		"pickup": {"x": pick.x, "z": pick.y, "radius": 2.4},
		"dropoff": {"x": drop.x, "z": drop.y, "radius": 2.4},
		"success": {"max_swing_deg": 90.0, "time_target_s": 9999.0},
		"rules": {"no_overload": false, "require_outriggers": false},
		"free": true,
	}


# --- construction --------------------------------------------------------------

func _build_world() -> void:
	MaterialLibrary.set_texture_generation(not _is_selftest())

	var builder_script: GDScript = load(EnvironmentCatalog.builder_path(GameState.environment_id))
	world = builder_script.new()
	world.weather_id = weather_id
	world.env_id = GameState.environment_id
	add_child(world)
	world.build({"weather": weather_id, "scenario": scenario})

	Weather.apply(self, weather_id, bool(env_spec.get("indoor", false)))
	if not bool(env_spec.get("indoor", false)) and not _is_selftest():
		precip = Weather.build_precipitation(weather_id)
		if precip != null:
			add_child(precip)

	_build_zone_markers()


func _build_zone_markers() -> void:
	for pair in [[scenario.get("pickup", {}), Color(0.98, 0.84, 0.10), "zone_a"],
			[scenario.get("dropoff", {}), Color(0.20, 0.62, 0.98), "zone_b"]]:
		var zone: Dictionary = pair[0]
		if zone.is_empty():
			continue
		var color: Color = pair[1]
		var pos := Vector3(float(zone.x), 0.0, float(zone.z))
		var radius := float(zone.get("radius", 1.8))
		world.floor_disc(pos, radius, Color(color.r, color.g, color.b, 0.45))
		world.zone_beacon(pos, color, 18.0)
		world.billboard(Loc.t(String(pair[2])), pos + Vector3(0.0, 2.6, 0.0), color, 30)


func _build_actors() -> void:
	var base: Vector3 = Vector3(world.machine_base)
	rig = MachineRigScript.new()
	rig.setup(spec, base)

	visual = MachineVisualScript.new()
	add_child(visual)
	visual.setup(spec, rig, base)

	sim = CableLoadSimScript.new()
	wind_model = WindModelScript.new()
	telemetry = TelemetryScript.new()
	runner = ScenarioRunnerScript.new()
	runner.load_scenario(scenario)
	access = MachineAccessScript.new()

	player = PlayerControllerScript.new()
	player.add_to_group("player")
	player.position = Vector3(world.player_spawn)
	add_child(player)

	load_body = LoadBodyScript.new()
	load_body.configure(load_size)
	add_child(load_body)
	load_body.player_hit.connect(_on_load_hit_player)

	load_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = load_size
	load_mesh.mesh = mesh
	load_mesh.material_override = MaterialLibrary.get_mat(
		String(scenario.get("load_material", "wood_pallet")))
	add_child(load_mesh)

	safety_ring = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = AppSettings.LOAD_SAFETY_RADIUS_M
	ring.bottom_radius = AppSettings.LOAD_SAFETY_RADIUS_M
	ring.height = 0.02
	safety_ring.mesh = ring
	safety_ring.material_override = MaterialLibrary.unshaded(Color(0.92, 0.18, 0.18, 0.16))
	add_child(safety_ring)

	cam = CameraDirectorScript.new()
	cam.player = player
	cam.rig = rig
	cam.visual = visual
	add_child(cam)
	# Frame the orbit view from the machine's actual height, and fence it
	# inside the building when the site has one.
	var g: Dictionary = spec.get("geometry", {})
	var machine_h: float = float(g.get("head_height", float(g.get("pivot_height", 8.0)) + 20.0))
	var indoor := bool(env_spec.get("indoor", false))
	var half_x: float = world.ground_half.x
	var half_z: float = world.ground_half.y
	var cx: float = world.ground_center.x
	var cz: float = world.ground_center.y
	var ceiling := 11.0 if indoor else 400.0
	cam.configure_framing(machine_h,
		Vector3(cx - half_x, 0.0, cz - half_z),
		Vector3(cx + half_x, ceiling, cz + half_z),
		indoor)
	if not bool(diff.get("show_hints", true)):
		# Assessment mode: no hook camera. You plan the lift or you do not.
		cam.allowed_modes = [cam.Mode.HOME, cam.Mode.ORBIT]


func _build_ui() -> void:
	hud = HudScript.new()
	add_child(hud)
	hud.build(spec, scenario, diff)

	pause_menu = PauseMenuScript.new()
	add_child(pause_menu)
	pause_menu.build()
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.restart_requested.connect(_on_restart)
	pause_menu.quit_requested.connect(_on_quit_to_menu)

	results = ResultsScript.new()
	add_child(results)
	results.build()
	results.retry_requested.connect(_on_restart)
	results.next_requested.connect(_on_next_scenario)
	results.menu_requested.connect(_on_quit_to_menu)


# --- lifecycle -------------------------------------------------------------------

## Resets the MACHINE and the job, never the operator's position — pressing
## reset inside the controls retries the lift, it does not teleport you.
func reset_all() -> void:
	rig.reset_to_home()
	sim.setup(rig.support_point(), rig.get_axis("hoist"), gross_kg,
		AppSettings.LOAD_DRAG_AREA_M2, AppSettings.LOAD_DRAG_CD, DT / SUBSTEPS)

	var base_wind := float(scenario.get("wind_ms", AppSettings.WIND_SPEED_MS))
	var shelter := EnvironmentCatalog.wind_shelter(GameState.environment_id)
	wind_model.setup(AppSettings.WIND_SEED,
		float(scenario.get("wind_dir_deg", AppSettings.WIND_DIR_DEG)),
		Weather.effective_wind_ms(weather_id, base_wind) * shelter,
		Weather.effective_gust_sigma(weather_id, AppSettings.WIND_GUST_SIGMA) * shelter,
		AppSettings.WIND_GUST_TAU_S)

	telemetry = TelemetryScript.new()
	runner.reset()
	for i in checks.size():
		checks[i] = false
	wind_enabled = true
	applied_wind = Vector3.ZERO
	elapsed_ticks = 0
	halted = false
	finished = false
	over_wind = false
	_prev_floor = false
	_prev_obstacle = false
	_prev_near = false
	_signal_text = ""
	_signal_timer = 0.0
	cam.reset_orbit()


func _physics_process(_delta: float) -> void:
	if finished or get_tree().paused:
		return

	if demo != null:
		demo.think(DT)

	access.update(DT, player.global_position, world.control_position,
		AppSettings.ACCESS_RADIUS_M)
	_handle_discrete()
	_drive_player()

	if halted:
		return

	var cmds := {}
	var fine := false
	if demo != null:
		cmds = demo.commands
		fine = demo.fine
	elif access.is_controlling():
		cmds = ControlScheme.read_commands(spec)
		cmds["outriggers"] = _outrigger_cmd
		fine = Input.is_action_pressed("fine_mode")
	rig.step(DT, cmds, fine)
	sim.cable_length = rig.get_axis("hoist")

	# Wind always advances so the seeded sequence at time t is identical no
	# matter when the operator toggles it; the toggle only gates application.
	wind_model.step(DT)
	applied_wind = wind_model.wind() if wind_enabled else Vector3.ZERO
	over_wind = Weather.over_wind_limit(weather_id, applied_wind.length())

	var target: Vector3 = rig.support_point()
	var prev: Vector3 = sim.support_pos
	for i in SUBSTEPS:
		sim.step(prev.lerp(target, float(i + 1) / float(SUBSTEPS)), applied_wind)

	if not (sim.load_pos.is_finite() and sim.load_vel.is_finite() and is_finite(sim.tension)):
		halted = true      # fail visibly; never continue corrupted state
		return

	elapsed_ticks += 1
	telemetry.record(elapsed_ticks * DT, sim.load_pos, sim.support_pos, sim.tension,
		rad_to_deg(sim.swing_angle_rad()), applied_wind)

	_resolve_impacts()
	load_body.sync_to_sim(sim.load_pos)
	_check_near_miss()
	_check_hazard_zones()
	_update_limits()
	_update_signaller(DT)

	runner.update(DT, {
		"load_x": _box_center().x,
		"load_z": _box_center().z,
		"load_height_m": _load_bottom(),
		"swing_deg": rad_to_deg(sim.swing_angle_rad()),
		"new_collisions": _tick_collisions,
		"new_violations": _tick_violations,
		"new_near_misses": _tick_near,
		"hazard_hit": _tick_hazard,
		"overloaded": lmi_status >= LoadChartScript.Status.OVERLOAD,
		"unstable": stability.get("level", 0) >= StabilityScript.Level.CRITICAL,
		"over_wind": over_wind,
		"fail_on_violation": bool(diff.get("fail_on_violation", false)),
	})
	_tick_collisions = 0
	_tick_violations = 0
	_tick_near = 0
	_tick_hazard = ""

	if runner.is_finished() and not bool(scenario.get("free", false)):
		_finish()


func _process(delta: float) -> void:
	if visual != null:
		visual.sync()
	cam.load_pos = _box_center()
	cam.use_cabin = access.is_controlling() and world.control_kind == "cabin" \
		and visual.has_cabin()
	cam.update(delta)
	_sync_load_visual()
	if hud != null:
		hud.update(delta, _hud_context())


func _sync_load_visual() -> void:
	var c := _box_center()
	load_mesh.position = c
	# The load hangs plumb below the rope head; rotating it with the swing
	# would be wrong (a slung load does not rotate with the rope angle).
	safety_ring.position = Vector3(c.x, 0.03, c.z)
	safety_ring.visible = bool(diff.get("show_hints", true)) or not access.is_controlling()


# --- input ------------------------------------------------------------------------

## Edge detector that works for hardware keys AND Input.action_press injected
## by the self-test, independent of node processing order.
func _edge(action: String) -> bool:
	var now := Input.is_action_pressed(action)
	var was: bool = _prev_action.get(action, false)
	_prev_action[action] = now
	return now and not was


func _handle_discrete() -> void:
	if _edge("pause_menu"):
		_toggle_pause()
		return
	if get_tree().paused:
		return

	if _edge("interact") and access.state == access.State.IN_ZONE:
		access.try_interact()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _edge("exit_machine") and access.is_controlling():
		# Leaving the controls before starting the lift, in conditions that
		# are over the limit, IS the correct answer on a refusal scenario —
		# and the only way the simulator can let an operator say "no". On any
		# other scenario it is just putting the controls down.
		if runner.phase == runner.Phase.NOT_STARTED and _should_refuse():
			runner.stop_work()
			access.try_exit()
			_finish()
			return
		access.try_exit()

	if access.is_controlling():
		for i in checks.size():
			if _edge("inspect_%d" % (i + 1)):
				checks[i] = true
				if not checks.has(false):
					rig.powered = true
		if _edge("outriggers_toggle"):
			# Toggle direction: press once to deploy, again to stow. Held
			# movement is continuous so the operator watches them go out.
			_outrigger_cmd = -1.0 if rig.outriggers > 0.5 else 1.0
		if Input.is_action_pressed("all_stop"):
			rig.emergency_stop = true
		elif rig.emergency_stop and not Input.is_action_pressed("all_stop"):
			rig.emergency_stop = false
		if _edge("signal_call"):
			_request_signal()
		if _edge("sim_reset"):
			reset_all()

	if _edge("wind_toggle"):
		wind_enabled = not wind_enabled
	if _edge("lang_toggle"):
		Loc.cycle()
	if _edge("camera_cycle"):
		cam.cycle_mode()
	if _edge("cam_reset"):
		cam.go_home() if cam.mode != cam.Mode.ORBIT else cam.reset_orbit()
	if _edge("help_toggle"):
		hud.toggle_help()
	if _edge("load_chart"):
		hud.toggle_chart()
	if _edge("map_toggle"):
		hud.toggle_map()
	if _edge("toggle_mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


## True when the conditions genuinely justify refusing the lift: over the
## wind limit, or the load is off the chart at the radius it sits at. Only
## scenarios that declare `stop_work_expected` score a refusal as a pass, but
## the condition itself is computed from the live state, not scripted — so a
## learner cannot pass by guessing that "this is the refusal one".
func _should_refuse() -> bool:
	return over_wind or lmi_status >= LoadChartScript.Status.OVERLOAD


## A pendant operator stands still while holding the control box; a cab
## operator is inside the machine. Either way they do not walk while driving.
func _drive_player() -> void:
	if demo != null:
		player.move_enabled = false
		if demo.walking:
			player.drive_forward(DT)
		else:
			player.velocity = Vector3.ZERO
		return
	if access.is_controlling():
		player.move_enabled = false
		player.velocity = Vector3.ZERO
		if world.control_kind == "cabin":
			player.global_position = world.control_position + Vector3(0.0, 0.1, 0.0)
		return
	player.move_enabled = true
	player.physics_step(DT)


# --- physics consequences -----------------------------------------------------------

## The load box's true centre: sim.load_pos is the cable ATTACHMENT point,
## `attach_offset` above the box centre. Every contact check must use this —
## an earlier version passed load_pos straight in and was silently wrong.
func _box_center() -> Vector3:
	return sim.load_pos - Vector3(0.0, load_body.attach_offset, 0.0)


func _load_bottom() -> float:
	return _box_center().y - load_size.y * 0.5


func _resolve_impacts() -> void:
	var c := _box_center()

	var floor_hit: bool = LoadBodyScript.check_floor_contact(c, load_size)
	if floor_hit:
		var r: Dictionary = LoadBodyScript.resolve_floor_contact(c, sim.load_vel,
			AppSettings.IMPACT_RESTITUTION, AppSettings.IMPACT_DAMPING, load_size)
		sim.load_pos = r.center + Vector3(0.0, load_body.attach_offset, 0.0)
		sim.load_vel = r.vel
		c = r.center
	# Setting a load down gently is the job; only a real impact scores. The
	# threshold is on approach speed, not on contact, or every successful
	# delivery would be logged as a collision.
	if floor_hit and not _prev_floor:
		if sim.load_vel.length() > 0.9 or absf(sim.load_vel.y) > 0.6:
			_register_impact("impact_floor")
	_prev_floor = floor_hit

	var obs: bool = LoadBodyScript.check_column_contact(c, world.obstacles, load_size)
	if obs:
		var r2: Dictionary = LoadBodyScript.resolve_column_contact(c, sim.load_vel,
			world.obstacles, AppSettings.IMPACT_RESTITUTION, AppSettings.IMPACT_DAMPING,
			load_size)
		sim.load_pos = r2.center + Vector3(0.0, load_body.attach_offset, 0.0)
		sim.load_vel = r2.vel
	if obs and not _prev_obstacle:
		_register_impact("impact_obstacle")
	_prev_obstacle = obs


func _register_impact(key: String) -> void:
	_tick_collisions += 1
	_tick_violations += 1
	load_body.hits_count += 1
	hud.flash_impact(key)
	cam.kick(1.0)


## Near-miss: the operator is inside the load's caution radius but not
## touching it — a lighter, separate volume from the exact contact box, per
## .claude/rules/simulation-physics.md.
func _check_near_miss() -> void:
	if access.is_controlling() and world.control_kind == "cabin":
		return   # you are inside the machine; you cannot be near-missed
	var near: bool = LoadBodyScript.is_within_safety_radius(_box_center(),
		player.global_position, AppSettings.LOAD_SAFETY_RADIUS_M)
	if near and not _prev_near:
		_tick_near += 1
		load_body.near_miss_count += 1
		hud.flash_caution()
	_prev_near = near


## Carrying a load over a scored area — a live traffic lane, a pavement, the
## open track, the water. Counted once per entry, not once per tick, so a
## slow transit and a fast one score the same violation.
func _check_hazard_zones() -> void:
	var c := _box_center()
	var bottom := _load_bottom()
	for z in world.hazard_zones:
		var rect: Rect2 = z.rect
		if not rect.has_point(Vector2(c.x, c.z)):
			continue
		if bottom < float(z.get("y_min", 0.05)) or bottom > float(z.get("y_max", 1000.0)):
			continue
		if _tick_hazard == "":
			_tick_hazard = String(z.key)
			_tick_violations += 1
			hud.flash_violation(String(z.key))
		return


func _on_load_hit_player(push_velocity: Vector3) -> void:
	if access.is_controlling():
		return
	_tick_collisions += 1
	_tick_violations += 1
	player.velocity += push_velocity
	hud.flash_danger()
	cam.kick(1.5)


## Load moment indication and stability, recomputed from the RESOLVED state.
func _update_limits() -> void:
	var chart: Array = spec.get("load_chart", [])
	var radius: float = rig.radius()
	lmi_capacity = LoadChartScript.capacity_at(chart, radius)
	lmi_util = LoadChartScript.utilisation(chart, radius, gross_kg)
	lmi_status = LoadChartScript.status_for(chart, radius, gross_kg)

	if spec.get("outriggers", {}).is_empty():
		stability = {"factor": INF, "level": StabilityScript.Level.STABLE,
			"level_key": "stab_stable", "color": Color(0.22, 0.86, 0.35),
			"tipping_side": "front", "tipping_distance_m": 0.0, "max_stable_radius_m": 1e9}
	else:
		stability = StabilityScript.evaluate(
			AppSettings.machine_mass_kg(String(spec.id)), gross_kg, radius,
			rig.support_half_extents(), rig.boom_yaw_rad())


## The signaller: presses B to ask what the operator cannot see. Returns the
## instruction that would actually move the load toward the current target,
## which is what a banksman does — it is help, not autopilot.
func _request_signal() -> void:
	var target: Dictionary = scenario.get("pickup", {}) if runner.phase == runner.Phase.NOT_STARTED \
		else scenario.get("dropoff", {})
	if target.is_empty():
		return
	var c := _box_center()
	var to := Vector2(float(target.x) - c.x, float(target.z) - c.z)
	if to.length() < float(target.get("radius", 1.8)):
		_signal_text = Loc.t("sig_hoist_down") if _load_bottom() > 0.4 else Loc.t("sig_stop")
	elif rig.has_axis("slew"):
		var want := rad_to_deg(atan2(to.y, to.x))
		var delta := wrapf(want - rig.get_axis("slew"), -180.0, 180.0)
		if absf(delta) > 6.0:
			_signal_text = Loc.t("sig_slew_left") if delta < 0.0 else Loc.t("sig_slew_right")
		else:
			_signal_text = Loc.t("sig_out") if to.length() > 1.0 else Loc.t("sig_in")
	else:
		_signal_text = Loc.t("sig_ok")
	_signal_timer = 4.0
	hud.flash_signal(_signal_text)


func _update_signaller(delta: float) -> void:
	if _signal_timer > 0.0:
		_signal_timer -= delta


# --- HUD feed ---------------------------------------------------------------------

func _hud_context() -> Dictionary:
	var pairs: Array = ControlScheme.pairs_for(spec)
	var state := {
		"controlling": access.is_controlling(),
		"in_zone": access.state == access.State.IN_ZONE,
		"needs_outriggers": bool(spec.get("needs_outriggers", false)),
		"outriggers_ready": rig.outriggers_ready(),
		"powered": rig.powered,
		"checks": checks,
		"phase": runner.phase_name(),
		"hook_low": _load_bottom() < 1.5,
		"near_target": _near_target(),
		"pairs": pairs,
		"control_point": world.control_position,
		"pickup_point": _zone_point(scenario.get("pickup", {})),
		"dropoff_point": _zone_point(scenario.get("dropoff", {})),
	}
	var step: String = GuidanceScript.current_step(state)
	return _hud_dict(step, state, pairs)


## Turns a Guidance step id into the sentence the learner reads, with THIS
## machine's actual keys substituted in — a tower-crane learner is told "A/D
## slew", an overhead-crane learner "A/D trolley", from the same step. Lives
## here rather than in Guidance so that module stays autoload-free and
## unit-testable (tests/module_tests.gd).
func _guidance_text(step: String, state: Dictionary, pairs: Array) -> String:
	var base := Loc.t(GuidanceScript.text_key(step))
	if step == "inspect":
		var missing := PackedStringArray()
		var keys := ["insp_1", "insp_2", "insp_3", "insp_4"]
		for i in checks.size():
			if not bool(checks[i]):
				missing.append("[%d] %s" % [i + 1, Loc.t(keys[i])])
		return "%s\n%s" % [base, "   ".join(missing)]

	var hint := GuidanceScript.axis_hint(step)
	if hint == "":
		return base
	var parts := PackedStringArray()
	for p in pairs:
		var is_hoist := String(p.axis) == "hoist"
		if (hint == "hoist" and is_hoist) or (hint == "*" and not is_hoist):
			parts.append("%s/%s  %s" % [p.keys[0], p.keys[1], p.label])
	if parts.is_empty():
		return base
	if step == "deliver":
		parts.append("SHIFT %s" % Loc.t("fine_short"))
	return "%s\n%s" % [base, "   ".join(parts)]


func _hud_dict(step: String, state: Dictionary, pairs: Array) -> Dictionary:
	return {
		"spec": spec,
		"scenario": scenario,
		"halted": halted,
		"powered": rig.powered,
		"checks": checks,
		"controlling": access.is_controlling(),
		"access_state": access.state_name(),
		"control_kind": world.control_kind,
		"outriggers": rig.outriggers,
		"needs_outriggers": bool(spec.get("needs_outriggers", false)),
		"estop": rig.emergency_stop,
		"axes": rig.axis,
		"radius_m": rig.radius(),
		"hook_height_m": _load_bottom(),
		"rope_out_m": rig.get_axis("hoist"),
		"swing_deg": rad_to_deg(sim.swing_angle_rad()),
		"tension_n": sim.tension,
		"gross_kg": gross_kg,
		"capacity_kg": lmi_capacity,
		"lmi_util": lmi_util,
		"lmi_status": lmi_status,
		"stability": stability,
		"wind": applied_wind,
		"wind_speed": applied_wind.length(),
		"wind_limit": float(Weather.get_preset(weather_id).get("wind_limit_ms", 99.0)),
		"over_wind": over_wind,
		"weather_id": weather_id,
		"time_s": elapsed_ticks * DT,
		"camera_view": cam.active_view_name(),
		"player_xz": Vector2(player.global_position.x, player.global_position.z),
		"load_xz": Vector2(_box_center().x, _box_center().z),
		"pickup": scenario.get("pickup", {}),
		"dropoff": scenario.get("dropoff", {}),
		"guidance_step": step,
		"guidance_text": _guidance_text(step, state, pairs),
		"guidance_target": GuidanceScript.target_point(state),
		"guidance_progress": GuidanceScript.progress(state),
		"live": runner.live(),
		"rigging": rigging_plan,
		"signal_text": _signal_text if _signal_timer > 0.0 else "",
		"telemetry_rows": telemetry.count(),
		"free": bool(scenario.get("free", false)),
	}


func _zone_point(zone: Dictionary):
	if zone.is_empty():
		return null
	return Vector3(float(zone.x), 0.5, float(zone.z))


func _near_target() -> bool:
	var target: Dictionary = scenario.get("dropoff", {}) if runner.phase == runner.Phase.CARRYING \
		else scenario.get("pickup", {})
	if target.is_empty():
		return false
	var c := _box_center()
	return Vector2(c.x - float(target.x), c.z - float(target.z)).length() \
		<= float(target.get("radius", 1.8)) * 1.8


# --- finish / menus -----------------------------------------------------------------

func _finish() -> void:
	finished = true
	var res: Dictionary = runner.result()
	if demo != null:
		# The pilot cannot report this itself: _physics_process returns early
		# once `finished` is set, so its own think() is never called again.
		print("[DEMO] %s — %s, %.0f points, %.0f s, swing %.1f deg, hits %d, viol %d %s" % [
			scenario.get("id", "free"), "PASS" if res.passed else "NOT YET",
			res.points, res.time_s, res.max_swing_deg, res.collisions, res.violations,
			str(res.violated) if not res.violated.is_empty() else ""])
	if not bool(scenario.get("free", false)):
		GameState.record_result(String(scenario.get("id", "")), res)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	results.show_result(res, scenario, spec)
	session_finished.emit(res)


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_menu.set_shown(paused, spec)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _on_resume() -> void:
	get_tree().paused = false
	pause_menu.set_shown(false, spec)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _on_next_scenario() -> void:
	var next := ScenarioDB.next_after(String(scenario.get("id", "")))
	if next != "":
		GameState.select_scenario(ScenarioDB.get_scenario(next))
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


# --- accessors used by the self-test driver -------------------------------------------

func is_controlling() -> bool:
	return access.is_controlling()


func get_camera_transform() -> Transform3D:
	return cam.camera.global_transform


func rope_visible() -> bool:
	return visual.rope.visible


func hud_status_text() -> String:
	return hud.status_label.text
