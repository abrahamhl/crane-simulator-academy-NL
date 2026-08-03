extends RefCounted
## MachineRig — one kinematic solver for every machine class in the catalogue.
##
## Replaces the slice-001 `crane_rig.gd` (bridge/trolley/hoist only), which is
## kept untouched so its original unit tests still pass. This rig is driven by
## a MachineCatalog spec: it owns whichever of the six axes that spec declares,
## integrates velocity commands with per-axis acceleration limits, clamps to
## limits, and resolves the ROPE HEAD position (`support_point()`) that
## CableLoadSim hangs the load from.
##
## Everything is deterministic, fixed-step and scene-free: no Node, no Input,
## no delta from the frame timer. Unit tested in tests/module_tests.gd.
##
## FRAME CONVENTION
##   world +X  : bridge / gantry / rail travel direction
##   world +Y  : up
##   world +Z  : trolley cross-travel for overhead & gantry
##   slew = 0  : boom / jib points along +X. Positive slew rotates towards +Z.
## `base` is the machine's footprint origin on the ground.

const Catalog := preload("res://core/machine_catalog.gd")

const DEG := PI / 180.0

var spec: Dictionary = {}
var base := Vector3.ZERO

## Current axis positions, keyed by axis name. Only declared axes exist.
var axis: Dictionary = {}
## Current axis velocities, same keys.
var axis_vel: Dictionary = {}

var powered := false
var fine_factor := 0.25

## Outrigger deployment 0..1. Machines without outriggers sit at 1.0 so every
## stability query treats them as fully supported.
var outriggers := 1.0
var outrigger_rate := 0.35     # units per second, ~3 s to deploy

var emergency_stop := false


func setup(p_spec: Dictionary, p_base: Vector3 = Vector3.ZERO) -> void:
	spec = p_spec
	base = p_base
	axis.clear()
	axis_vel.clear()
	var home: Dictionary = spec.get("geometry", {}).get("home", {})
	for name in spec.get("axes", {}):
		var a: Dictionary = spec.axes[name]
		axis[name] = float(home.get(name, a.min))
		axis_vel[name] = 0.0
	powered = false
	emergency_stop = false
	outriggers = 0.0 if spec.get("needs_outriggers", false) else 1.0


func has_axis(name: String) -> bool:
	return axis.has(name)


func get_axis(name: String, fallback: float = 0.0) -> float:
	return float(axis.get(name, fallback))


func axis_fraction(name: String) -> float:
	if not axis.has(name):
		return 0.0
	var a: Dictionary = spec.axes[name]
	var span: float = float(a.max) - float(a.min)
	if absf(span) < 0.0001:
		return 0.0
	return clampf((float(axis[name]) - float(a.min)) / span, 0.0, 1.0)


## Advance one fixed step. `cmds` maps axis name -> command in [-1, 1];
## missing axes are treated as zero. `fine` engages the slow/precision mode
## every real crane control has, scaling BOTH speed and the reachable
## acceleration so fine mode is genuinely gentler, not just slower.
func step(dt: float, cmds: Dictionary, fine: bool = false) -> void:
	var f := fine_factor if fine else 1.0
	var live := powered and not emergency_stop

	# Outriggers move whenever the machine is powered, independent of the
	# motion axes — you set up before you lift, and you can stow after.
	if spec.get("needs_outriggers", false):
		var og := float(cmds.get("outriggers", 0.0))
		if live and absf(og) > 0.01:
			outriggers = clampf(outriggers + signf(og) * outrigger_rate * dt, 0.0, 1.0)

	for name in axis:
		var a: Dictionary = spec.axes[name]
		var cmd := 0.0
		if live and _axis_permitted(name):
			cmd = clampf(float(cmds.get(name, 0.0)), -1.0, 1.0)
		var target: float = cmd * float(a.speed) * f
		var accel: float = float(a.accel) * (f if fine else 1.0)
		# Braking is never slowed by fine mode: a stop command must always be
		# able to stop the machine at full authority.
		if absf(target) < absf(axis_vel[name]) or emergency_stop:
			accel = float(a.accel)
		if emergency_stop:
			target = 0.0
			accel = float(a.accel) * 3.0
		axis_vel[name] = move_toward(float(axis_vel[name]), target, accel * dt)

		var v: float = float(axis[name]) + float(axis_vel[name]) * dt
		if a.get("wraps", false):
			v = wrapf(v, float(a.min), float(a.max))
		else:
			if v <= float(a.min) or v >= float(a.max):
				v = clampf(v, float(a.min), float(a.max))
				axis_vel[name] = 0.0
		axis[name] = v


## Motion interlock: a machine that needs outriggers must not slew, luff,
## telescope or travel until they are down. Hoisting is still allowed so the
## operator can take up slack — that mirrors how the interlocks are actually
## taught (set up, then work), and makes the rule discoverable rather than
## just freezing every control with no explanation.
func _axis_permitted(name: String) -> bool:
	if not spec.get("needs_outriggers", false):
		return true
	if outriggers >= 0.99:
		return true
	return name == "hoist"


func outriggers_ready() -> bool:
	return outriggers >= 0.99


## Half-extents of the current support polygon, shrinking as the outriggers
## retract. Fed to StabilityModel; machines without outriggers report a wide,
## effectively non-binding footprint since their stability is structural.
func support_half_extents() -> Vector2:
	var og: Dictionary = spec.get("outriggers", {})
	if og.is_empty():
		return Vector2(1000.0, 1000.0)
	return Vector2(
		lerpf(float(og.retracted_half_x), float(og.half_x), outriggers),
		lerpf(float(og.retracted_half_z), float(og.half_z), outriggers))


# --- kinematics --------------------------------------------------------------

## Height of the rope head above the ground at the machine's base.
func head_height() -> float:
	return support_point().y


## World position of the point the rope hangs from. This is THE output of the
## rig — CableLoadSim needs nothing else from the machine.
func support_point() -> Vector3:
	match String(spec.get("class", Catalog.CLASS_OVERHEAD)):
		Catalog.CLASS_TOWER:
			return _tower_head()
		Catalog.CLASS_MOBILE, Catalog.CLASS_LOADER:
			return _boom_tip()
		Catalog.CLASS_RAILWAY:
			return _boom_tip()
		_:
			return _bridge_head()


## Overhead & gantry: the head is simply the trolley on the bridge.
func _bridge_head() -> Vector3:
	var g: Dictionary = spec.get("geometry", {})
	return base + Vector3(get_axis("travel"), float(g.get("head_height", 9.0)),
		get_axis("trolley"))


## Tower crane: the trolley runs out along a horizontal jib that slews.
func _tower_head() -> Vector3:
	var g: Dictionary = spec.get("geometry", {})
	var r := get_axis("trolley")
	var s := get_axis("slew") * DEG
	return base + Vector3(cos(s) * r, float(g.get("head_height", 40.0)), sin(s) * r)


## Mobile / lorry-loader / railway: the head is the tip of a boom that slews,
## luffs and (except on the fixed lattice boom) telescopes.
func _boom_tip() -> Vector3:
	var g: Dictionary = spec.get("geometry", {})
	# A rail-mounted crane's slew centre travels with the machine along the
	# track, so the travel axis has to shift the pivot — not just the visual.
	# Radius stays measured from the slew centre wherever that centre now is,
	# which is exactly why "drive closer" is a valid answer to an overload.
	var pivot := base + Vector3(get_axis("travel", 0.0),
		float(g.get("pivot_height", 2.5)), 0.0)
	var length := get_axis("telescope", float(g.get("boom_length", 20.0)))
	var l := get_axis("luff") * DEG
	var s := get_axis("slew") * DEG
	var horiz := cos(l) * length
	return pivot + Vector3(cos(s) * horiz, sin(l) * length, sin(s) * horiz)


## Working radius: horizontal distance from the SLEW CENTRE to the rope. This
## is the number every load chart is indexed by, so it is defined here once
## and never recomputed ad hoc elsewhere.
##
## For overhead and gantry cranes there is no slew centre and no radius-based
## derating, so radius is reported as 0 and LoadChart returns a flat capacity.
func radius() -> float:
	match String(spec.get("class", Catalog.CLASS_OVERHEAD)):
		Catalog.CLASS_TOWER:
			return get_axis("trolley")
		Catalog.CLASS_MOBILE, Catalog.CLASS_LOADER, Catalog.CLASS_RAILWAY:
			var g: Dictionary = spec.get("geometry", {})
			var length := get_axis("telescope", float(g.get("boom_length", 20.0)))
			return cos(get_axis("luff") * DEG) * length
		_:
			return 0.0


## Hook height above the machine's ground plane, given the current rope payout.
func hook_height() -> float:
	return support_point().y - get_axis("hoist") - base.y


## Direction the boom/jib points, for placing visuals and the cabin camera.
func boom_yaw_rad() -> float:
	return get_axis("slew") * DEG


## True while any axis is actually moving — drives motor sound and the
## "machine in motion" HUD state.
func is_moving() -> bool:
	for name in axis_vel:
		if absf(float(axis_vel[name])) > 0.005:
			return true
	return false


func fastest_axis_fraction() -> float:
	var worst := 0.0
	for name in axis_vel:
		var a: Dictionary = spec.axes[name]
		worst = maxf(worst, absf(float(axis_vel[name])) / maxf(0.0001, float(a.speed)))
	return clampf(worst, 0.0, 1.0)


## Snap every axis back to its home pose and stop it dead. Used by the
## session reset (R) — resets the MACHINE, never the operator's position.
func reset_to_home() -> void:
	var home: Dictionary = spec.get("geometry", {}).get("home", {})
	for name in axis:
		axis[name] = float(home.get(name, spec.axes[name].min))
		axis_vel[name] = 0.0
	powered = false
	emergency_stop = false
	outriggers = 0.0 if spec.get("needs_outriggers", false) else 1.0
