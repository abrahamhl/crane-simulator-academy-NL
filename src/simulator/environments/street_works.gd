extends "res://environments/env_base.gd"
## Street works, city centre — the site for the lorry loader and the smaller
## mobile crane set-ups.
##
## The whole point of this environment is CONSTRAINT. The road runs along X;
## the machine stands in a closed lane at the origin; there is a live traffic
## lane on one side, a pavement with the public on the other, building
## facades three metres beyond that, and an overhead tram/lighting wire the
## boom must stay under. Almost every failure here is a planning failure
## rather than a control failure, which is exactly the lesson.

const ROAD_HALF_Z := 7.0
const KERB_Z := 7.0
const PAVEMENT_Z := 10.0
const FACADE_Z := 13.0
const WIRE_HEIGHT := 8.4


func build(_ctx: Dictionary) -> void:
	machine_base = Vector3.ZERO
	player_spawn = Vector3(-9.0, 0.2, 7.5)

	ground(Vector2(70.0, 34.0), Vector2(0.0, 0.0), ground_material_for(M.ASPHALT))
	boundary_walls(10.0)

	_road()
	_pavements_and_facades()
	_closed_lane()
	_traffic()
	_overhead_wires()

	control_station(Vector3(-4.6, 0.0, 3.4), "ground")

	# The two areas the load must never cross. They are drawn on the ground as
	# well as scored, so the constraint is visible before it is violated.
	hazard_zone(Rect2(-35.0, -ROAD_HALF_Z, 70.0, 4.6), "violation_public",
		Color(0.95, 0.25, 0.15, 0.13))                       # live traffic lane
	hazard_zone(Rect2(-35.0, KERB_Z, 70.0, 5.0), "violation_public",
		Color(0.95, 0.25, 0.15, 0.13))                       # public pavement

	maybe_worklights([
		Vector3(-8.0, 6.0, 2.0), Vector3(8.0, 6.0, 2.0),
		Vector3(0.0, 6.0, -3.0), Vector3(0.0, 6.0, 6.0),
	])


func _road() -> void:
	box(Vector3(70.0, 0.02, 12.0), Vector3(0.0, 0.02, 0.0), M.TARMAC)
	# Centre line between the live lane and the closed one.
	for i in 22:
		var x := -34.0 + float(i) * 3.2
		floor_line(Vector3(x, 0.0, -2.4), Vector3(x + 1.8, 0.0, -2.4), 0.14,
			Color(0.92, 0.92, 0.90, 0.9))
	floor_line(Vector3(-35.0, 0.0, ROAD_HALF_Z - 0.35), Vector3(35.0, 0.0, ROAD_HALF_Z - 0.35),
		0.12, Color(0.92, 0.92, 0.90, 0.75))
	# Manhole covers and a patched trench: small details, big realism payoff.
	for i in 5:
		box(Vector3(0.7, 0.03, 0.7), Vector3(-24.0 + float(i) * 12.0, 0.035, 4.2), M.STEEL_RUSTY)
	box(Vector3(9.0, 0.04, 2.2), Vector3(2.0, 0.04, 4.0), M.CONCRETE_DIRTY)


func _pavements_and_facades() -> void:
	for side in [1.0, -1.0]:
		var z: float = KERB_Z * side
		solid(Vector3(70.0, 0.16, 0.3), Vector3(0.0, 0.08, z), M.CONCRETE)
		box(Vector3(70.0, 0.14, 6.0), Vector3(0.0, 0.07, z + 3.0 * side), M.CONCRETE)

	# Facades: a row of buildings with window bands. They box the site in and
	# make the slew limits feel physical rather than arbitrary.
	for i in 9:
		var x := -32.0 + float(i) * 8.0
		var h := 11.0 + float((i * 7) % 4) * 3.0
		var mat := M.BRICK if i % 2 == 0 else M.CONCRETE
		hazard_solid(Vector3(7.4, h, 5.0), Vector3(x, h * 0.5, FACADE_Z + 2.5), mat)
		for f in int(h / 3.2):
			box(Vector3(6.0, 1.4, 0.12), Vector3(x, 2.4 + float(f) * 3.2, FACADE_Z + 0.02), M.GLASS)
		hazard_solid(Vector3(7.4, h - 2.0, 5.0), Vector3(x, (h - 2.0) * 0.5, -FACADE_Z - 2.5), mat)

	# Street furniture on the public side — the things people stand next to.
	for i in 6:
		var x := -28.0 + float(i) * 11.0
		box(Vector3(0.16, 4.4, 0.16), Vector3(x, 2.2, PAVEMENT_Z - 0.6), M.STEEL_GALV)
		box(Vector3(0.9, 0.14, 0.35), Vector3(x, 4.35, PAVEMENT_Z - 1.0), M.STEEL_PAINTED)


## The lane the crane occupies: cones, barriers, signs and a laydown area.
func _closed_lane() -> void:
	barrier_run(Vector3(-13.0, 0.0, -2.6), Vector3(13.0, 0.0, -2.6))
	barrier_run(Vector3(-13.0, 0.0, KERB_Z - 0.6), Vector3(13.0, 0.0, KERB_Z - 0.6))
	barrier_run(Vector3(-13.0, 0.0, -2.6), Vector3(-13.0, 0.0, KERB_Z - 0.6))
	barrier_run(Vector3(13.0, 0.0, -2.6), Vector3(13.0, 0.0, KERB_Z - 0.6))

	for i in 12:
		var t := float(i) / 11.0
		_cone(Vector3(lerpf(-20.0, -13.5, t), 0.0, lerpf(-5.6, -2.6, t)))
		_cone(Vector3(lerpf(20.0, 13.5, t), 0.0, lerpf(-5.6, -2.6, t)))

	# Site sign at each end of the closure.
	for x in [-15.0, 15.0]:
		box(Vector3(0.10, 2.0, 0.10), Vector3(x, 1.0, 1.0), M.STEEL_GALV)
		box(Vector3(1.4, 1.0, 0.06), Vector3(x, 2.2, 1.0), M.HAZARD_STRIPE)
	billboard("LANE CLOSED · RIJSTROOK DICHT", Vector3(-15.0, 3.1, 1.0),
		Color(0.98, 0.78, 0.1), 22)


func _cone(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.22
	cyl.height = 0.72
	mi.mesh = cyl
	mi.material_override = MaterialLibrary.get_mat(M.CRANE_ORANGE)
	mi.position = pos + Vector3(0.0, 0.36, 0.0)
	add_child(mi)
	box(Vector3(0.44, 0.03, 0.44), pos + Vector3(0.0, 0.02, 0.0), M.RUBBER)


## Parked and moving vehicles. Parked cars are real obstacles for the load;
## the live lane is scored as a hazard zone rather than modelled with traffic
## AI, because a load swung over a live lane is a violation whether or not a
## car happens to be under it at that instant.
func _traffic() -> void:
	var colors := [M.CONTAINER_BLUE, M.CONTAINER_RED, M.CONTAINER_GREY, M.CONTAINER_GREEN]
	for i in 8:
		var x := -30.0 + float(i) * 8.5
		if absf(x) < 15.0:
			continue
		var c: String = colors[i % colors.size()]
		hazard_solid(Vector3(4.3, 1.05, 1.8), Vector3(x, 0.62, 5.4), c)
		box(Vector3(2.3, 0.62, 1.66), Vector3(x - 0.2, 1.42, 5.4), M.GLASS)
		for wx in [-1.45, 1.45]:
			for wz in [-0.85, 0.85]:
				box(Vector3(0.62, 0.62, 0.24), Vector3(x + wx, 0.31, 5.4 + wz), M.RUBBER)

	# The delivery lorry the loader crane is mounted on — placed at the origin
	# so the machine visually belongs to something.
	hazard_solid(Vector3(9.0, 1.2, 2.5), Vector3(0.0, 1.0, 0.0), M.CONTAINER_BLUE)
	box(Vector3(2.6, 1.7, 2.4), Vector3(-3.4, 2.35, 0.0), M.CONTAINER_BLUE)
	box(Vector3(1.6, 0.8, 2.2), Vector3(-4.3, 2.6, 0.0), M.GLASS)
	for wx in [-3.2, 2.2, 3.6]:
		for wz in [-1.1, 1.1]:
			box(Vector3(1.0, 1.0, 0.36), Vector3(wx, 0.5, wz), M.RUBBER)


## Overhead line at 8.4 m: the boom and the load must stay under it. Drawn as
## catenary segments between poles so it is unmistakable from the cab.
func _overhead_wires() -> void:
	for i in 8:
		var x := -30.0 + float(i) * 8.6
		box(Vector3(0.20, WIRE_HEIGHT, 0.20), Vector3(x, WIRE_HEIGHT * 0.5, PAVEMENT_Z + 1.2),
			M.STEEL_GALV)
		box(Vector3(0.14, 0.14, 3.2), Vector3(x, WIRE_HEIGHT - 0.3, PAVEMENT_Z - 0.4), M.STEEL_GALV)
	for lane_z in [-1.0, 3.0]:
		box(Vector3(66.0, 0.05, 0.05), Vector3(0.0, WIRE_HEIGHT - 0.35, lane_z), M.CABLE)
	# Registered as an obstacle so a boom-tip strike is detected, not just
	# drawn: a wire you can pass through teaches the opposite of the lesson.
	obstacle_only(Vector3(66.0, 0.5, 5.0), Vector3(0.0, WIRE_HEIGHT - 0.35, 1.0))
	# Height-banded: only a load raised into the wire's clearance envelope
	# breaks this rule. Working underneath it at normal carrying height is
	# exactly what the closed lane is for.
	hazard_zone(Rect2(-33.0, -1.6, 66.0, 5.2), "violation_line",
		Color(0.95, 0.55, 0.05, 0.10), WIRE_HEIGHT - 2.2, 1000.0)
