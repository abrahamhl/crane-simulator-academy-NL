extends RefCounted
## Rigging — sling geometry, leg tension and gross-load arithmetic.
##
## The failure a lifting examiner probes hardest is not driving the crane: it
## is a candidate who computes the gross load wrong, or who does not know that
## closing a two-leg sling from 60° to 30° nearly doubles the tension in each
## leg. Those are the two things this module makes computable, checkable and
## therefore teachable inside a scenario.
##
## Angle convention: `angle_deg` is the angle of a sling leg ABOVE THE
## HORIZONTAL — the convention printed on sling tags and used in lifting
## training. 90° is a vertical leg (best case); small angles are dangerous.
## Beware the other convention (included angle at the hook); they are not the
## same number and mixing them up is itself a classic exam trap, so this
## module only ever accepts the angle-to-horizontal and says so in the name.
##
## Pure static math, unit tested directly.

const G := 9.80665

## Below this sling angle the configuration is rejected outright. Industry
## practice is to not rig below 30° to the horizontal: the leg tension is
## already double the vertical share and rises without bound thereafter.
const MIN_SAFE_ANGLE_DEG := 30.0

## Standard mode factors for a multi-leg sling. A 4-leg sling is NOT rated on
## four legs: with a rigid load you cannot guarantee more than three take
## load, and conventional practice rates it on two. Encoding the conservative
## convention here is deliberate — a learner who internalises "4 legs = 4x"
## has learned the wrong thing.
const EFFECTIVE_LEGS := {1: 1.0, 2: 2.0, 3: 3.0, 4: 2.0}


## Tension in ONE sling leg, in newtons.
## T_leg = W / (n_effective * sin(angle_to_horizontal))
static func leg_tension_n(gross_kg: float, legs: int, angle_deg: float) -> float:
	var n: float = EFFECTIVE_LEGS.get(clampi(legs, 1, 4), 1.0)
	var a := deg_to_rad(clampf(angle_deg, 1.0, 90.0))
	var s := sin(a)
	if s < 0.0001:
		return INF
	return (gross_kg * G) / (n * s)


## The multiplier a learner is asked to quote: how much MORE tension than the
## straight vertical share this angle creates. 90° -> 1.00, 60° -> 1.155,
## 45° -> 1.414, 30° -> 2.00.
static func angle_factor(angle_deg: float) -> float:
	var s := sin(deg_to_rad(clampf(angle_deg, 1.0, 90.0)))
	return INF if s < 0.0001 else 1.0 / s


static func is_angle_acceptable(angle_deg: float) -> bool:
	return angle_deg >= MIN_SAFE_ANGLE_DEG


## Gross load = payload + every piece of hardware hanging below the hook.
## Forgetting the block and the spreader beam is the most common way a lift
## that "fits the chart" actually does not.
static func gross_load_kg(payload_kg: float, below_hook_kg: float) -> float:
	return maxf(0.0, payload_kg) + maxf(0.0, below_hook_kg)


## Working Load Limit check for the chosen sling set.
static func slings_adequate(gross_kg: float, legs: int, angle_deg: float,
		wll_per_leg_kg: float) -> bool:
	if not is_angle_acceptable(angle_deg):
		return false
	var t_kg := leg_tension_n(gross_kg, legs, angle_deg) / G
	return t_kg <= wll_per_leg_kg


## Minimum sling WLL per leg (kg) needed for this lift — the number the
## candidate must be able to produce before touching the crane.
static func required_wll_per_leg_kg(gross_kg: float, legs: int, angle_deg: float) -> float:
	return leg_tension_n(gross_kg, legs, angle_deg) / G


## Sling angle actually produced by a given geometry: legs of `leg_length_m`
## reaching from the hook down to attachment points `half_span_m` out from the
## load's centreline. Lets a scenario derive the angle from the load it
## specifies instead of asserting a number.
static func angle_from_geometry_deg(leg_length_m: float, half_span_m: float) -> float:
	if leg_length_m <= 0.0001:
		return 90.0
	var ratio := clampf(half_span_m / leg_length_m, 0.0, 1.0)
	return rad_to_deg(acos(ratio))


## Centre-of-gravity offset check. A load slung off its centre of gravity
## tilts and can slip; scenarios use this to fail an eccentric pick.
## Returns the tilt angle in degrees the load will hang at.
static func hang_tilt_deg(cg_offset_m: float, sling_height_m: float) -> float:
	if sling_height_m <= 0.0001:
		return 90.0
	return rad_to_deg(atan(absf(cg_offset_m) / sling_height_m))


## Summary block for the HUD / rigging-plan screen. Everything the operator
## should have written down before the lift.
static func plan(payload_kg: float, below_hook_kg: float, legs: int,
		angle_deg: float, wll_per_leg_kg: float) -> Dictionary:
	var gross := gross_load_kg(payload_kg, below_hook_kg)
	return {
		"payload_kg": payload_kg,
		"below_hook_kg": below_hook_kg,
		"gross_kg": gross,
		"legs": legs,
		"angle_deg": angle_deg,
		"angle_factor": angle_factor(angle_deg),
		"leg_tension_kg": leg_tension_n(gross, legs, angle_deg) / G,
		"required_wll_kg": required_wll_per_leg_kg(gross, legs, angle_deg),
		"wll_per_leg_kg": wll_per_leg_kg,
		"angle_acceptable": is_angle_acceptable(angle_deg),
		"adequate": slings_adequate(gross, legs, angle_deg, wll_per_leg_kg),
	}
