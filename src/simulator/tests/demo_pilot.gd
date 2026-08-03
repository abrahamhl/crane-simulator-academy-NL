extends Node
## DemoPilot — drives the machine through a complete lift with no human input.
##
## Two jobs, and it earns its place on both:
##   1. Video and GIF capture for the README, the itch.io page and LinkedIn.
##      A still screenshot cannot show swing control, and a human driving badly
##      on camera is worse than no video.
##   2. An attract loop on the itch.io build, so a visitor who never touches a
##      key still sees what the simulator does.
##
## It is a PROPORTIONAL CONTROLLER over the same command dictionary a player
## produces, not a scripted animation: it reads the live rig state, works out
## which way each axis has to move to put the hook over the target, and feeds
## commands through `rig.step` exactly as `ControlScheme.read_commands` would.
## That means the physics, the load swing, the interlocks and the scoring all
## behave identically to a played session — if the pilot can complete a lift,
## a player can.
##
## It deliberately drives GENTLY (creep near the target, waits for swing to
## settle before setting down) because the footage doubles as a demonstration
## of how the job should be done.
##
## Run:  godot --path src/simulator res://game/session.tscn -- --demo --scenario=SC-101

const HEADER := "[DEMO]"

## Command magnitude when far from target vs. closing in. The controller never
## commands full speed near the target, for the same reason an operator does
## not: a load that arrives still swinging cannot be placed.
const FAST := 1.0
const SLOW := 0.35

## Tolerances, in the units of each axis.
const LINEAR_TOL := 0.35      # m
const SLEW_TOL := 1.2         # degrees
const RADIUS_TOL := 0.5       # m

## Swing the pilot will tolerate before it stops and lets the load settle.
##
## 6 s was not enough: a 5 m rope has a period around 4.5 s, so the pilot was
## still setting down with the load moving and scoring a ground strike — the
## impact check counts total speed, and a load that skids as it lands is a
## fault whether or not it came down gently. Waiting properly is also the
## behaviour the footage should be demonstrating.
const SETTLE_SWING_DEG := 1.2
const SETTLE_MAX_S := 25.0

var session: Node3D

## Read by session.gd each tick INSTEAD of the input map. The pilot never calls
## rig.step itself — the session remains the only place the simulation
## advances, so the documented tick order still holds exactly.
var commands: Dictionary = {}
var fine := false
var walking := false

var _phase := "approach"
var _settle := 0.0
var _done := false


func _ready() -> void:
	session = get_parent()
	session.demo = self
	print("%s pilot attached to %s" % [HEADER, session.scenario.get("id", "free")])


## Called by session.gd before it steps the rig.
func think(delta: float) -> void:
	commands = {}
	walking = false
	fine = false
	if _done or session.rig == null:
		return
	match _phase:
		"approach": _approach()
		"setup": _setup()
		"work": _work(delta)


## Walk to the control position and take the controls. Teleporting would skip
## the part of the video that shows there IS a control position to walk to.
func _approach() -> void:
	var target: Vector3 = session.world.control_position
	var here: Vector3 = session.player.global_position
	var to := Vector3(target.x - here.x, 0.0, target.z - here.z)
	if to.length() > AppSettings.ACCESS_RADIUS_M * 0.6:
		# Face the control station and walk, using the real character body.
		session.player.look_at_target(target)
		walking = true
		return
	session.access.update(0.0, here, target, AppSettings.ACCESS_RADIUS_M)
	session.access.try_interact()
	_phase = "setup"


## Outriggers, then the pre-use checks — in that order, because that is the
## order the interlock enforces and the order the video should teach.
func _setup() -> void:
	var rig = session.rig
	rig.powered = true
	if bool(session.spec.get("needs_outriggers", false)) and not rig.outriggers_ready():
		commands["outriggers"] = 1.0
		return
	for i in session.checks.size():
		session.checks[i] = true
	_phase = "work"


func _work(delta: float) -> void:
	var runner = session.runner
	if runner.is_finished():
		if not _done:
			_done = true
			print("%s lift complete: %s, %.0f points" % [HEADER,
				runner.phase_name(), runner.points()])
		return

	var target: Dictionary = session.scenario.get("pickup", {}) \
		if runner.phase == runner.Phase.NOT_STARTED else session.scenario.get("dropoff", {})
	if target.is_empty():
		return

	var xz := Vector2(float(target.x), float(target.z))
	commands = _commands_toward(xz, delta)
	# Creep whenever the hook is close, exactly as the tutorial teaches.
	fine = _hook_offset(xz).length() < 3.0


## Horizontal offset from the hook's current ground position to the target.
func _hook_offset(target: Vector2) -> Vector2:
	var head: Vector3 = session.rig.support_point()
	return target - Vector2(head.x, head.z)


## Proportional commands per axis. Each machine class is steered through the
## axes it actually has — the same dispatch MachineRig uses.
func _commands_toward(target: Vector2, delta: float) -> Dictionary:
	var rig = session.rig
	var cmds := {}
	var offset := _hook_offset(target)
	var close := offset.length() < 2.5

	match String(session.spec["class"]):
		MachineCatalog.CLASS_OVERHEAD, MachineCatalog.CLASS_GANTRY:
			cmds["travel"] = _axis_cmd(offset.x, LINEAR_TOL)
			cmds["trolley"] = _axis_cmd(offset.y, LINEAR_TOL)
		MachineCatalog.CLASS_TOWER:
			var want_deg := rad_to_deg(atan2(target.y, target.x))
			cmds["slew"] = _angle_cmd(want_deg - rig.get_axis("slew"))
			cmds["trolley"] = _axis_cmd(target.length() - rig.get_axis("trolley"), RADIUS_TOL)
		_:
			var base_x: float = rig.get_axis("travel", 0.0)
			var rel := Vector2(target.x - base_x, target.y)
			# A rail crane drives along the track first so the radius it has to
			# work at is the smallest one available — the SC-504 lesson.
			if rig.has_axis("travel"):
				cmds["travel"] = _axis_cmd(target.x - base_x - _preferred_standoff(rel), 0.6)
			var want_deg := rad_to_deg(atan2(rel.y, rel.x))
			cmds["slew"] = _angle_cmd(want_deg - rig.get_axis("slew"))
			var radius_err: float = rel.length() - rig.radius()
			if rig.has_axis("telescope"):
				cmds["telescope"] = _axis_cmd(radius_err, RADIUS_TOL)
			else:
				# Fixed boom: the only way to change radius is to luff.
				cmds["luff"] = _axis_cmd(-radius_err, RADIUS_TOL)

	cmds["hoist"] = _hoist_cmd(close, delta)

	# Anti-swing. A load already swinging cannot be placed, so the pilot backs
	# off the horizontal axes as the swing grows and stops driving entirely
	# past the limit — which is exactly the technique the scenarios teach, and
	# it is worth showing on camera rather than just saying in a briefing.
	var swing := rad_to_deg(session.sim.swing_angle_rad())
	var limit: float = float(ScenarioDB.success_of(session.scenario).max_swing_deg)
	var damp := clampf(1.0 - (swing / maxf(1.0, limit * 0.7)), 0.0, 1.0)
	for axis_name in ["travel", "trolley", "slew", "telescope", "luff"]:
		if cmds.has(axis_name):
			cmds[axis_name] = float(cmds[axis_name]) * damp
	return cmds


## Where a travelling machine should stand relative to the target: close
## enough that the boom works at a short radius, without driving on top of it.
func _preferred_standoff(rel: Vector2) -> float:
	return signf(rel.x) * maxf(0.0, absf(rel.x) - maxf(4.0, absf(rel.y)))


func _axis_cmd(error: float, tol: float) -> float:
	if absf(error) <= tol:
		return 0.0
	return signf(error) * (FAST if absf(error) > tol * 6.0 else SLOW)


func _angle_cmd(error_deg: float) -> float:
	var e := wrapf(error_deg, -180.0, 180.0)
	if absf(e) <= SLEW_TOL:
		return 0.0
	return signf(e) * (FAST if absf(e) > 25.0 else SLOW)


## Lower onto the target once the hook is over it AND the load has settled;
## otherwise carry at a safe height. Waiting for the swing to stop is the
## whole point of the footage.
func _hoist_cmd(close: bool, delta: float) -> float:
	var swing := rad_to_deg(session.sim.swing_angle_rad())
	var bottom: float = session._load_bottom()

	if not close:
		_settle = 0.0
		# Carry at roughly 2 m clearance.
		return _axis_cmd(2.0 - bottom, 0.25) * -1.0

	if swing > SETTLE_SWING_DEG and _settle < SETTLE_MAX_S:
		_settle += delta
		return 0.0
	return 1.0 if bottom > 0.15 else 0.0
