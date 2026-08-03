extends RefCounted
## Guidance — the always-on instructor, as a pure state machine.
##
## The single biggest failure of the previous build was that a player could
## stand in the hall with no idea what to do or which key to press. This
## module fixes that structurally: given the session's state it returns THE
## one thing to do next. It is a pure function of state — no timers, no
## scripted sequence — so it recovers correctly no matter what order the
## player does things in, including undoing a step.
##
## Steps are ordered by dependency and the first incomplete one wins.
## Deliberately NOT a linear tutorial the player can fall out of.
##
## No Loc dependency by design: this file must be testable without autoloads
## (see tests/module_tests.gd). It returns step ids and the localisation KEY
## for each; the session turns those into sentences with the machine's own
## key bindings substituted in.

const STEPS := [
	"approach", "take_controls", "outriggers", "inspect",
	"lower_hook", "attach", "travel", "deliver", "release",
]

## step id -> the Loc key its instruction lives under.
const TEXT_KEYS := {
	"approach": "tut_welcome",
	"take_controls": "tut_take",
	"outriggers": "tut_outriggers",
	"inspect": "tut_inspect",
	"lower_hook": "tut_hoist",
	"attach": "tut_hoist",
	"travel": "tut_travel",
	"deliver": "tut_deliver",
	"release": "tut_done",
}

## Which axis's keys are worth printing alongside each step's instruction.
## "" means the step is not about a particular control.
const AXIS_HINT := {
	"lower_hook": "hoist",
	"attach": "hoist",
	"deliver": "hoist",
	"travel": "*",     # every axis except the hoist
}


## `s` is the state dictionary session.gd assembles each frame:
##   controlling, in_zone, needs_outriggers, outriggers_ready, powered,
##   phase ("not_started"|"carrying"|"delivered"), hook_low, near_target
static func current_step(s: Dictionary) -> String:
	if not bool(s.get("controlling", false)):
		return "take_controls" if bool(s.get("in_zone", false)) else "approach"
	if bool(s.get("needs_outriggers", false)) and not bool(s.get("outriggers_ready", false)):
		return "outriggers"
	if not bool(s.get("powered", false)):
		return "inspect"
	match String(s.get("phase", "not_started")):
		"carrying":
			return "deliver" if bool(s.get("near_target", false)) else "travel"
		"delivered", "stopped_work", "failed":
			return "release"
		_:
			return "lower_hook" if not bool(s.get("hook_low", false)) else "attach"


static func text_key(step: String) -> String:
	return String(TEXT_KEYS.get(step, ""))


static func axis_hint(step: String) -> String:
	return String(AXIS_HINT.get(step, ""))


## Which world point the guidance arrow should point at right now, or null
## when there is nothing to point at.
static func target_point(s: Dictionary):
	match current_step(s):
		"approach", "take_controls", "outriggers", "inspect":
			return s.get("control_point", null)
		"lower_hook", "attach":
			return s.get("pickup_point", null)
		"travel", "deliver":
			return s.get("dropoff_point", null)
		_:
			return null


## Progress through the whole lift, 0..1 — drives the HUD's step strip so the
## learner can see how far through the job they are.
static func progress(s: Dictionary) -> float:
	var i := STEPS.find(current_step(s))
	if i < 0:
		return 0.0
	return float(i) / float(STEPS.size() - 1)


static func step_index(step: String) -> int:
	return maxi(0, STEPS.find(step))
