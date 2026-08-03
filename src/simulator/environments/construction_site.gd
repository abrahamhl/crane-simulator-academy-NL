extends "res://environments/env_base.gd"
## Housing construction site — the tower crane's world, and the large set-up
## area for the mobile crane.
##
## The teaching value here is RADIUS and BLINDNESS. The concrete frame stands
## between the crane and half its working area, so a large part of the job is
## done on the signaller's word rather than by eye, and the load chart bites
## long before the machine runs out of jib.

const FRAME_X := 26.0
const FRAME_Z := 6.0
const FLOOR_H := 3.2
const FLOORS := 5


func build(_ctx: Dictionary) -> void:
	machine_base = Vector3.ZERO
	player_spawn = Vector3(16.0, 0.2, 16.0)

	ground(Vector2(110.0, 110.0), Vector2(0.0, 0.0), ground_material_for(M.SOIL))
	boundary_walls(12.0)

	_haul_road()
	_frame()
	_laydown()
	_compound()
	_perimeter()

	control_station(Vector3(4.6, 0.0, -4.6), "cabin")

	# The site compound is where the people are — canteen, offices, the fuel
	# store. The laydown area and the frame are deliberately NOT hazards:
	# those are where the work is, and a rule that forbids the job teaches
	# nothing. This is the one area a load must never cross.
	hazard_zone(Rect2(-36.0, 13.0, 16.0, 17.0), "violation_public",
		Color(0.95, 0.25, 0.15, 0.12))

	maybe_worklights([
		Vector3(FRAME_X, 18.0, FRAME_Z + 9.0), Vector3(FRAME_X, 18.0, FRAME_Z - 9.0),
		Vector3(-22.0, 9.0, 22.0), Vector3(22.0, 9.0, -22.0), Vector3(0.0, 12.0, 0.0),
	])


## Compacted haul road looping the site — gives the ground a readable
## structure and marks where vehicles (and therefore people) actually are.
func _haul_road() -> void:
	box(Vector3(90.0, 0.03, 7.0), Vector3(0.0, 0.03, 26.0), M.GRAVEL)
	box(Vector3(7.0, 0.03, 60.0), Vector3(-30.0, 0.03, 0.0), M.GRAVEL)
	box(Vector3(30.0, 0.03, 6.0), Vector3(-14.0, 0.03, -22.0), M.GRAVEL)
	for i in 14:
		floor_line(Vector3(-42.0 + float(i) * 6.4, 0.0, 22.6),
			Vector3(-39.0 + float(i) * 6.4, 0.0, 22.6), 0.12, Color(0.95, 0.85, 0.1, 0.5))


## The rising concrete frame: slabs, columns and a stair core. Every slab edge
## is a real obstacle and a real place to set a load down.
func _frame() -> void:
	for f in FLOORS:
		var y := float(f + 1) * FLOOR_H
		hazard_solid(Vector3(24.0, 0.32, 13.0), Vector3(FRAME_X, y, FRAME_Z), M.CONCRETE)
		# Edge protection on the top two floors only — below that the facade
		# is going on, which is what a real site looks like mid-build.
		if f >= FLOORS - 2:
			for edge in [-6.5, 6.5]:
				barrier_run(Vector3(FRAME_X - 12.0, y + 0.16, FRAME_Z + edge),
					Vector3(FRAME_X + 12.0, y + 0.16, FRAME_Z + edge))
		for cx in [-10.0, -3.0, 3.0, 10.0]:
			for cz in [-5.0, 5.0]:
				hazard_solid(Vector3(0.5, FLOOR_H - 0.32, 0.5),
					Vector3(FRAME_X + cx, y - FLOOR_H * 0.5, FRAME_Z + cz), M.CONCRETE_DIRTY)
	# Stair/lift core rising a floor above the frame.
	hazard_solid(Vector3(5.0, FLOOR_H * (FLOORS + 1), 5.0),
		Vector3(FRAME_X - 13.5, FLOOR_H * (FLOORS + 1) * 0.5, FRAME_Z), M.CONCRETE)
	# Scaffold on the near face.
	for i in 9:
		var z := FRAME_Z - 6.0 + float(i) * 1.5
		box(Vector3(0.08, FLOOR_H * FLOORS, 0.08), Vector3(FRAME_X - 12.9, FLOOR_H * FLOORS * 0.5, z),
			M.STEEL_GALV)
	obstacle_only(Vector3(1.4, FLOOR_H * FLOORS, 13.0),
		Vector3(FRAME_X - 12.9, FLOOR_H * FLOORS * 0.5, FRAME_Z))
	billboard("BLOCK A", Vector3(FRAME_X, FLOOR_H * FLOORS + 2.6, FRAME_Z - 7.0),
		Color(0.85, 0.88, 0.92), 34)


## Materials laid out at known radii — the pick points for most scenarios.
func _laydown() -> void:
	# Rebar bundles.
	for i in 6:
		var z := 14.0 + float(i) * 1.4
		hazard_solid(Vector3(11.0, 0.5, 1.0), Vector3(-14.0, 0.25, z), M.STEEL_RUSTY)
	# Precast panels stood in an A-frame rack.
	for i in 4:
		hazard_solid(Vector3(0.25, 3.2, 6.0), Vector3(-24.0 + float(i) * 0.9, 1.6, -8.0), M.CONCRETE)
	box(Vector3(4.6, 0.3, 6.4), Vector3(-22.6, 0.15, -8.0), M.STEEL_PAINTED)
	# Timber and formwork stacks.
	for i in 3:
		hazard_solid(Vector3(4.8, 1.0, 2.4), Vector3(-6.0 + float(i) * 6.0, 0.5, -18.0), M.WOOD)
	# Concrete blocks on pallets, the generic pick.
	for i in 5:
		pallet_stack(Vector3(8.0 + float(i) * 2.6, 0.0, 18.0), 2)
	# Skips.
	hazard_solid(Vector3(5.4, 1.6, 2.2), Vector3(-30.0, 0.8, 8.0), M.CRANE_YELLOW)
	hazard_solid(Vector3(5.4, 1.6, 2.2), Vector3(-30.0, 0.8, 11.0), M.STEEL_RUSTY)


## Site compound: cabins, welfare, fuel store. The place people are.
func _compound() -> void:
	for i in 4:
		var z := 17.0 + float(i) * 3.4
		hazard_solid(Vector3(9.0, 2.8, 3.0), Vector3(-26.0, 1.4, z), M.CONTAINER_BLUE)
		box(Vector3(1.6, 1.0, 0.08), Vector3(-26.0, 1.9, z - 1.55), M.GLASS)
		box(Vector3(0.9, 2.0, 0.10), Vector3(-22.0, 1.0, z - 1.55), M.STEEL_PAINTED)
	hazard_solid(Vector3(3.0, 2.4, 2.4), Vector3(-34.0, 1.2, 12.0), M.CRANE_RED)
	billboard("SITE OFFICE", Vector3(-26.0, 3.6, 17.0), Color(0.85, 0.9, 0.95), 24)


func _perimeter() -> void:
	var half := 44.0
	for i in 36:
		var t := float(i) / 36.0 * TAU
		var p := Vector3(cos(t) * half, 0.0, sin(t) * half)
		box(Vector3(0.10, 2.4, 0.10), p + Vector3(0.0, 1.2, 0.0), M.STEEL_GALV)
	for i in 36:
		var a := float(i) / 36.0 * TAU
		var b := float(i + 1) / 36.0 * TAU
		var pa := Vector3(cos(a) * half, 1.2, sin(a) * half)
		var pb := Vector3(cos(b) * half, 1.2, sin(b) * half)
		var mid := (pa + pb) * 0.5
		var d := pb - pa
		var mi := box(Vector3(Vector2(d.x, d.z).length(), 2.2, 0.05), mid, M.STEEL_GALV)
		mi.rotation.y = -atan2(d.z, d.x)
