extends "res://environments/env_base.gd"
## Rail maintenance yard — the rail-mounted slewing crane's world.
##
## The rule that makes rail work different from every other site: the machine
## is confined to ONE track inside a possession, and the track beside it is
## not. Slewing a load over the adjacent line is the cardinal error, and the
## overhead line above it is live. Both are modelled as scored hazard zones,
## and both are drawn plainly enough that the operator can see the limit
## before crossing it.
##
## Tracks run along X. Track 1 (z = 0) is the possession the crane works from.
## Track 2 (z = 4.5) is open to traffic.

const SLEEPER_SPACING := 0.6
const GAUGE := 1.435
const OHL_HEIGHT := 5.6
const TRACK_Z := [0.0, 4.5, 9.0, 13.5]


func build(_ctx: Dictionary) -> void:
	machine_base = Vector3.ZERO
	player_spawn = Vector3(24.0, 0.2, 18.0)

	ground(Vector2(100.0, 46.0), Vector2(40.0, 8.0), ground_material_for(M.BALLAST))
	boundary_walls(10.0)

	_tracks()
	_overhead_line()
	_material_stacks()
	_yard_buildings()
	_possession_markers()

	control_station(Vector3(6.0, 0.0, -4.4), "cabin")

	# The adjacent open track, plus the electrical clearance envelope around
	# the contact wire. Different keys so the debrief can say WHICH rule broke.
	hazard_zone(Rect2(-12.0, TRACK_Z[1] - 2.2, 104.0, 4.4), "violation_track",
		Color(0.95, 0.25, 0.15, 0.14))
	hazard_zone(Rect2(-12.0, TRACK_Z[1] - 1.6, 104.0, 3.2), "violation_line",
		Color(0.98, 0.62, 0.06, 0.10), OHL_HEIGHT - 2.0, 1000.0)

	maybe_worklights([
		Vector3(14.0, 8.0, -6.0), Vector3(40.0, 8.0, -6.0), Vector3(66.0, 8.0, -6.0),
		Vector3(28.0, 8.0, 18.0), Vector3(56.0, 8.0, 18.0),
	])


func _tracks() -> void:
	for ti in TRACK_Z.size():
		var z: float = TRACK_Z[ti]
		box(Vector3(104.0, 0.22, 3.4), Vector3(40.0, 0.06, z), M.BALLAST)
		for i in int(104.0 / SLEEPER_SPACING):
			var x := -12.0 + float(i) * SLEEPER_SPACING
			box(Vector3(0.26, 0.16, 2.6), Vector3(x, 0.16, z), M.CONCRETE_DIRTY)
		for side in [-GAUGE * 0.5, GAUGE * 0.5]:
			box(Vector3(104.0, 0.16, 0.08), Vector3(40.0, 0.30, z + side), M.RAIL_STEEL)
		# Only the working track and the live one get a beacon-style label —
		# the far sidings are scenery.
		if ti <= 1:
			var label := "TRACK 1 — POSSESSION" if ti == 0 else "TRACK 2 — OPEN TO TRAFFIC"
			var col := Color(0.3, 0.85, 0.45) if ti == 0 else Color(0.95, 0.25, 0.15)
			billboard(label, Vector3(20.0, 2.4, z), col, 24)
			billboard(label, Vector3(64.0, 2.4, z), col, 24)


## Masts, cantilevers and the contact wire. The wire is registered as a load
## obstacle so a boom or load that reaches it is detected, not ignored.
func _overhead_line() -> void:
	for i in 14:
		var x := -8.0 + float(i) * 7.6
		hazard_solid(Vector3(0.28, OHL_HEIGHT + 0.8, 0.28),
			Vector3(x, (OHL_HEIGHT + 0.8) * 0.5, TRACK_Z[1] + 3.4), M.STEEL_GALV)
		box(Vector3(0.14, 0.14, 4.4), Vector3(x, OHL_HEIGHT + 0.5, TRACK_Z[1] + 1.4), M.STEEL_GALV)
		box(Vector3(0.10, 0.5, 0.10), Vector3(x, OHL_HEIGHT + 0.2, TRACK_Z[1]), M.STEEL_GALV)
	box(Vector3(104.0, 0.06, 0.06), Vector3(40.0, OHL_HEIGHT, TRACK_Z[1]), M.CABLE)
	box(Vector3(104.0, 0.05, 0.05), Vector3(40.0, OHL_HEIGHT + 0.9, TRACK_Z[1]), M.CABLE)
	obstacle_only(Vector3(104.0, 0.8, 0.9), Vector3(40.0, OHL_HEIGHT, TRACK_Z[1]))
	billboard("⚡ LIVE OVERHEAD LINE — 1500 V DC", Vector3(40.0, OHL_HEIGHT + 2.0, TRACK_Z[1]),
		Color(0.98, 0.78, 0.1), 26)


## Sleeper and rail stacks alongside the possession — the picks and the
## set-downs for most rail scenarios, at realistic radii from track 1.
func _material_stacks() -> void:
	for s in 4:
		var x := 12.0 + float(s) * 16.0
		for layer in 4:
			hazard_solid(Vector3(2.8, 0.18, 2.6), Vector3(x, 0.28 + float(layer) * 0.20, -5.0),
				M.CONCRETE_DIRTY)
	for s in 3:
		var x := 20.0 + float(s) * 20.0
		for layer in 3:
			hazard_solid(Vector3(18.0, 0.16, 0.9), Vector3(x, 0.30 + float(layer) * 0.18, -9.0),
				M.RAIL_STEEL)
	# Ballast bags and a points/turnout panel waiting to go in.
	for i in 5:
		hazard_solid(Vector3(1.1, 1.1, 1.1), Vector3(56.0 + float(i) * 1.4, 0.55, 17.0), M.SAND)
	hazard_solid(Vector3(9.0, 0.5, 3.2), Vector3(30.0, 0.25, 19.0), M.STEEL_RUSTY)
	billboard("TURNOUT PANEL", Vector3(30.0, 1.6, 19.0), Color(0.9, 0.9, 0.95), 22)


func _yard_buildings() -> void:
	hazard_solid(Vector3(24.0, 7.0, 12.0), Vector3(78.0, 3.5, 22.0), M.CORRUGATED)
	box(Vector3(6.0, 5.0, 0.2), Vector3(72.0, 2.5, 16.1), M.STEEL_PAINTED)
	billboard("MAINTENANCE SHED", Vector3(78.0, 8.0, 16.0), Color(0.85, 0.88, 0.92), 26)
	for i in 3:
		hazard_solid(Vector3(9.0, 2.8, 3.0), Vector3(4.0, 1.4, 16.0 + float(i) * 3.4),
			M.CONTAINER_GREEN)
	# Signal gantry at the far end.
	box(Vector3(0.3, 7.0, 0.3), Vector3(92.0, 3.5, -2.0), M.STEEL_GALV)
	box(Vector3(0.3, 0.3, 18.0), Vector3(92.0, 6.9, 6.0), M.STEEL_GALV)
	for ti in TRACK_Z.size():
		box(Vector3(0.5, 0.9, 0.35), Vector3(92.0, 6.2, TRACK_Z[ti]), M.STEEL_PAINTED)


## Possession limit boards: the physical markers that say where the safe
## working area starts and stops.
func _possession_markers() -> void:
	for x in [0.0, 84.0]:
		box(Vector3(0.12, 2.2, 0.12), Vector3(x, 1.1, TRACK_Z[0] - 2.4), M.STEEL_GALV)
		box(Vector3(0.05, 1.0, 1.0), Vector3(x, 2.2, TRACK_Z[0] - 2.4), M.HAZARD_STRIPE)
		billboard("POSSESSION LIMIT", Vector3(x, 3.1, TRACK_Z[0] - 2.4),
			Color(0.98, 0.78, 0.1), 22)
	floor_line(Vector3(0.0, 0.0, TRACK_Z[0] - 2.4), Vector3(0.0, 0.0, TRACK_Z[1] + 2.4), 0.2,
		Color(0.98, 0.78, 0.1, 0.8))
	floor_line(Vector3(84.0, 0.0, TRACK_Z[0] - 2.4), Vector3(84.0, 0.0, TRACK_Z[1] + 2.4), 0.2,
		Color(0.98, 0.78, 0.1, 0.8))
