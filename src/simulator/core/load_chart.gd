extends RefCounted
## LoadChart — rated-capacity lookup and load-moment indication.
##
## Reading a load chart and keeping the load moment inside the envelope is the
## single most-examined skill for mobile and tower crane licences. This module
## implements the arithmetic; the numbers themselves come from the machine spec
## and are declared TRAINING ENVELOPES, not manufacturer data (see
## machine_catalog.gd). Nothing here should ever be quoted as a rated capacity
## for a real machine.
##
## Chart format: an Array of [radius_m, capacity_kg] pairs, sorted ascending by
## radius. A single-entry chart means constant capacity at any radius (overhead
## and gantry cranes), which is the correct physical model for them, not a
## simplification.
##
## Pure static math, no scene dependency — unit tested directly.

enum Status { SAFE, NOTICE, WARNING, OVERLOAD, OUT_OF_CHART }

## Load Moment Indicator thresholds, as a fraction of rated capacity. These
## mirror the banding a real LMI display uses: an early advisory, an amber
## pre-alarm, then the cut-out. Chosen for training legibility.
const NOTICE_FRAC := 0.75
const WARNING_FRAC := 0.90
const OVERLOAD_FRAC := 1.00


## Rated capacity (kg) at a working radius. Below the chart's first radius the
## machine is still inside its minimum-radius plateau, so the first capacity
## applies. Beyond the last radius there is NO rating — the honest answer is
## "off the chart", returned as 0.0, never an extrapolated guess.
static func capacity_at(chart: Array, radius_m: float) -> float:
	if chart.is_empty():
		return 0.0
	if chart.size() == 1:
		return float(chart[0][1])
	if radius_m <= float(chart[0][0]):
		return float(chart[0][1])
	if radius_m > float(chart[chart.size() - 1][0]):
		return 0.0
	for i in range(1, chart.size()):
		var r0: float = float(chart[i - 1][0])
		var r1: float = float(chart[i][0])
		if radius_m <= r1:
			var c0: float = float(chart[i - 1][1])
			var c1: float = float(chart[i][1])
			var span := r1 - r0
			if absf(span) < 0.0001:
				return c1
			return lerpf(c0, c1, (radius_m - r0) / span)
	return 0.0


## True when the radius is past the end of the chart — the machine physically
## reaches there but has no rating for it. Treated as an immediate overload.
static func is_out_of_chart(chart: Array, radius_m: float) -> bool:
	if chart.size() <= 1:
		return false
	return radius_m > float(chart[chart.size() - 1][0])


## Fraction of rated capacity currently used, 0..n. Above 1.0 is an overload.
## Gross load = payload + everything below the hook (block, spreader, slings).
static func utilisation(chart: Array, radius_m: float, gross_kg: float) -> float:
	if is_out_of_chart(chart, radius_m):
		return 99.0
	var cap := capacity_at(chart, radius_m)
	if cap <= 0.0:
		return 99.0
	return gross_kg / cap


static func status_for(chart: Array, radius_m: float, gross_kg: float) -> Status:
	if is_out_of_chart(chart, radius_m):
		return Status.OUT_OF_CHART
	var u := utilisation(chart, radius_m, gross_kg)
	if u >= OVERLOAD_FRAC:
		return Status.OVERLOAD
	if u >= WARNING_FRAC:
		return Status.WARNING
	if u >= NOTICE_FRAC:
		return Status.NOTICE
	return Status.SAFE


static func status_key(status: Status) -> String:
	match status:
		Status.OUT_OF_CHART: return "lmi_out_of_chart"
		Status.OVERLOAD: return "lmi_overload"
		Status.WARNING: return "lmi_warning"
		Status.NOTICE: return "lmi_notice"
		_: return "lmi_safe"


static func status_color(status: Status) -> Color:
	match status:
		Status.OUT_OF_CHART, Status.OVERLOAD: return Color(0.95, 0.16, 0.14)
		Status.WARNING: return Color(0.98, 0.62, 0.06)
		Status.NOTICE: return Color(0.96, 0.86, 0.12)
		_: return Color(0.22, 0.86, 0.35)


## Load moment in tonne-metres — the quantity a crane is actually rated by,
## and the one an examiner will ask a candidate to state out loud.
static func load_moment_tm(radius_m: float, gross_kg: float) -> float:
	return (gross_kg / 1000.0) * radius_m


## The largest radius at which `gross_kg` may still be carried. This answers
## the question the operator actually has to plan around: "how far out can I
## take this load?" Returns 0.0 if the load exceeds capacity even at minimum
## radius (i.e. the lift is impossible on this machine).
static func max_radius_for(chart: Array, gross_kg: float) -> float:
	if chart.is_empty():
		return 0.0
	if chart.size() == 1:
		return 1e9 if gross_kg <= float(chart[0][1]) else 0.0
	if gross_kg > float(chart[0][1]):
		return 0.0
	var best: float = float(chart[0][0])
	for i in range(1, chart.size()):
		var r0: float = float(chart[i - 1][0])
		var r1: float = float(chart[i][0])
		var c0: float = float(chart[i - 1][1])
		var c1: float = float(chart[i][1])
		if gross_kg >= c1:
			# Crossing point inside this segment.
			if absf(c0 - c1) < 0.0001:
				return r1 if gross_kg <= c1 else r0
			return r0 + (r1 - r0) * (c0 - gross_kg) / (c0 - c1)
		best = r1
	return best


## Human-readable chart rows for the in-game load-chart screen: the operator
## must be able to LOOK UP the value, not just be told the answer by the HUD.
static func rows(chart: Array) -> Array:
	var out: Array = []
	for pair in chart:
		out.append({"radius_m": float(pair[0]), "capacity_kg": float(pair[1])})
	return out
