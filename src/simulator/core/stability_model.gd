extends RefCounted
## StabilityModel — tipping-over margin for outrigger-supported machines.
##
## Why this exists: a mobile crane does not fail by snapping its boom, it
## fails by going over sideways, and the direction it is slewed matters more
## than the weight it is holding. A candidate has to feel that "the same load
## is fine over the rear and lethal over the side". This module makes that
## difference explicit and scoreable.
##
## MODEL (deliberately a training model, stated plainly):
##   The support polygon is a rectangle of half-extents (half_x, half_z) taken
##   from the machine's outriggers. A machine tips about an EDGE of that
##   rectangle, not about a point, so every moment here is taken about the edge
##   the load is currently working over:
##
##     lever_x = |radius * cos(bearing)|      distance out over the front/rear
##     lever_z = |radius * sin(bearing)|      distance out over a side
##     the binding edge is whichever of lever_x/half_x, lever_z/half_z is larger
##     d       = half_x or half_z, for that edge   (the resisting arm)
##     lever   = lever_x or lever_z, for that edge (the load's arm)
##
##   Resisting moment   = machine_mass * g * d
##   Overturning moment = gross_load * g * (lever - d), counted only once the
##                        load is OUTSIDE the polygon; inside it, the load is
##                        still helping hold the machine down.
##
##   This reproduces the behaviour that matters: over a CORNER the load's arm
##   perpendicular to either edge is only r/sqrt(2), so a corner is markedly
##   more stable than the middle of a side at the same radius — which is why
##   set-up orientation is taught at all.
##
##   Reported margin is the ratio resisting/overturning. Real crane practice
##   works to a stability factor well above 1; the bands below reflect that.
##
## This does NOT model dynamic effects (swinging load, sudden braking, ground
## bearing failure) — those are handled elsewhere or acknowledged as absent.
## Nothing here should be read as a certified stability calculation.

const G := 9.80665

## Stability factor bands. Real regulation works with a required factor above
## 1.0 against a *static* tipping calculation precisely because dynamics eat
## the margin; 1.25 is used here as the training "green" floor.
const FACTOR_SAFE := 1.50
const FACTOR_CAUTION := 1.25
const FACTOR_CRITICAL := 1.05

enum Level { STABLE, CAUTION, CRITICAL, TIPPING }


## Which edge the load is working over, and the two arms about it.
## Returns {d, lever}: `d` is the machine's resisting arm (the half-extent to
## that edge) and `lever` is the load's arm measured the same way.
static func edge_arms(half: Vector2, radius_m: float, bearing_rad: float) -> Dictionary:
	if half.x <= 0.0001 or half.y <= 0.0001:
		return {"d": 0.0, "lever": radius_m}
	var lever_x := absf(cos(bearing_rad)) * radius_m
	var lever_z := absf(sin(bearing_rad)) * radius_m
	# The binding edge is the one the load is proportionally furthest over.
	if lever_x / half.x >= lever_z / half.y:
		return {"d": half.x, "lever": lever_x}
	return {"d": half.y, "lever": lever_z}


## The machine's resisting arm about the edge it would tip over on this
## bearing — the half-extent to that edge.
static func tipping_distance(half: Vector2, bearing_rad: float) -> float:
	# Radius cancels out of the edge choice, so any positive radius picks the
	# same edge; 1.0 keeps this usable as a pure geometry query.
	return float(edge_arms(half, 1.0, bearing_rad).d)


## Static stability factor. > 1 means the machine stays down.
## machine_mass_kg is the counterweighted machine acting at the slew centre.
static func stability_factor(machine_mass_kg: float, gross_load_kg: float,
		radius_m: float, half: Vector2, bearing_rad: float) -> float:
	var arms := edge_arms(half, radius_m, bearing_rad)
	var d: float = arms.d
	if d <= 0.0001:
		return 0.0
	var overhang: float = float(arms.lever) - d
	if overhang <= 0.0:
		return INF   # load still inside the support polygon: cannot tip on it
	var resisting := machine_mass_kg * G * d
	var overturning := gross_load_kg * G * overhang
	if overturning <= 0.0001:
		return INF
	return resisting / overturning


static func level_for(factor: float) -> Level:
	if factor >= FACTOR_SAFE:
		return Level.STABLE
	if factor >= FACTOR_CAUTION:
		return Level.CAUTION
	if factor >= FACTOR_CRITICAL:
		return Level.CRITICAL
	return Level.TIPPING


static func level_key(level: Level) -> String:
	match level:
		Level.TIPPING: return "stab_tipping"
		Level.CRITICAL: return "stab_critical"
		Level.CAUTION: return "stab_caution"
		_: return "stab_stable"


static func level_color(level: Level) -> Color:
	match level:
		Level.TIPPING: return Color(0.95, 0.16, 0.14)
		Level.CRITICAL: return Color(0.98, 0.45, 0.06)
		Level.CAUTION: return Color(0.96, 0.86, 0.12)
		_: return Color(0.22, 0.86, 0.35)


## The maximum radius at which this load keeps a given stability factor on
## this bearing — the planning answer, not just the alarm.
static func max_stable_radius(machine_mass_kg: float, gross_load_kg: float,
		half: Vector2, bearing_rad: float, required_factor: float = FACTOR_SAFE) -> float:
	if gross_load_kg <= 0.0001 or required_factor <= 0.0001:
		return 1e9
	var arms := edge_arms(half, 1.0, bearing_rad)
	var d: float = arms.d
	# `lever` at unit radius is the fraction of radius that acts on this edge,
	# so the limiting radius has to be scaled back up by it.
	var per_metre: float = maxf(0.0001, float(arms.lever))
	# resisting / (load * overhang) = factor  =>  overhang = resisting / (load*factor)
	var max_lever := d + (machine_mass_kg * d) / (gross_load_kg * required_factor)
	return max_lever / per_metre


## Which side the machine is most likely to go over, for the HUD's outrigger
## diagram. Returns "front" | "rear" | "left" | "right" in the machine's own
## frame, where the boom at bearing 0 points to the machine's front (+X).
static func tipping_side(bearing_rad: float) -> String:
	var deg := rad_to_deg(wrapf(bearing_rad, -PI, PI))
	if deg >= -45.0 and deg < 45.0:
		return "front"
	if deg >= 45.0 and deg < 135.0:
		return "right"
	if deg < -45.0 and deg >= -135.0:
		return "left"
	return "rear"


## Full evaluation for the HUD and the scoring system in one call.
static func evaluate(machine_mass_kg: float, gross_load_kg: float, radius_m: float,
		half: Vector2, bearing_rad: float) -> Dictionary:
	var factor := stability_factor(machine_mass_kg, gross_load_kg, radius_m, half, bearing_rad)
	var level := level_for(factor)
	return {
		"factor": factor,
		"level": level,
		"level_key": level_key(level),
		"color": level_color(level),
		"tipping_distance_m": tipping_distance(half, bearing_rad),
		"tipping_side": tipping_side(bearing_rad),
		"max_stable_radius_m": max_stable_radius(machine_mass_kg, gross_load_kg, half, bearing_rad),
	}
