extends "res://environments/env_base.gd"
## Container terminal quay — the ship-to-shore gantry's world.
##
## What this site teaches that no other does: absolute precision under
## absolute exposure. The tolerances are centimetres (a container either
## lands on its twistlocks or it does not), the crane is fully wind-exposed,
## and for part of every cycle the load hangs over open water where dropping
## it is unrecoverable.
##
## Layout: quay edge along z = 0, water to -Z, container stack and truck lanes
## to +Z, gantry travelling along X.

const QUAY_EDGE_Z := 0.0
const WATER_HALF := 40.0
const STACK_Z := 24.0


func build(_ctx: Dictionary) -> void:
	machine_base = Vector3.ZERO
	player_spawn = Vector3(30.0, 0.2, 34.0)

	ground(Vector2(120.0, 80.0), Vector2(40.0, 22.0), M.CONCRETE)
	boundary_walls(14.0)

	_water_and_edge()
	_vessel()
	_stacks()
	_lanes()
	_gantry_rails()

	control_station(Vector3(6.0, 0.0, 12.0), "cabin")

	# Only the water is off-limits. The truck lane is the DESTINATION for most
	# of the work here, so marking it a hazard would contradict the job — the
	# rule that actually applies at a container terminal is "never let the box
	# hang over the side", and that is what is scored.
	hazard_zone(Rect2(-24.0, -WATER_HALF, 128.0, WATER_HALF - 3.0), "violation_water",
		Color(0.15, 0.45, 0.95, 0.10))

	maybe_worklights([
		Vector3(12.0, 26.0, 10.0), Vector3(40.0, 26.0, 10.0), Vector3(68.0, 26.0, 10.0),
		Vector3(20.0, 14.0, 30.0), Vector3(60.0, 14.0, 30.0),
	])


func _water_and_edge() -> void:
	# Water plane sits just below the quay so the drop is visible and real.
	box(Vector3(180.0, 0.4, WATER_HALF * 2.0), Vector3(40.0, -1.6, -WATER_HALF), M.WATER)
	# Quay wall and fender line.
	solid(Vector3(150.0, 3.0, 1.2), Vector3(40.0, -1.4, QUAY_EDGE_Z - 0.6), M.CONCRETE_DIRTY)
	floor_line(Vector3(-30.0, 0.0, 1.2), Vector3(110.0, 0.0, 1.2), 0.25,
		Color(0.95, 0.82, 0.10, 0.95))
	for i in 30:
		var x := -26.0 + float(i) * 4.6
		box(Vector3(0.7, 1.0, 0.5), Vector3(x, -0.4, QUAY_EDGE_Z - 0.9), M.RUBBER)
	# Bollards.
	for i in 15:
		var x := -24.0 + float(i) * 9.2
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.30
		cyl.bottom_radius = 0.42
		cyl.height = 1.0
		mi.mesh = cyl
		mi.material_override = MaterialLibrary.get_mat(M.STEEL_RUSTY)
		mi.position = Vector3(x, 0.5, 2.2)
		add_child(mi)
		obstacle_only(Vector3(0.9, 1.0, 0.9), Vector3(x, 0.5, 2.2))


## The moored vessel: a hull, a deckhouse, and open holds with containers
## already stowed — the target most scenarios lift from or to.
func _vessel() -> void:
	var hull_z := -14.0
	hazard_solid(Vector3(130.0, 9.0, 22.0), Vector3(44.0, 2.4, hull_z), M.CONTAINER_RED)
	box(Vector3(130.0, 1.2, 22.6), Vector3(44.0, 7.0, hull_z), M.STEEL_RUSTY)
	# Deckhouse aft.
	hazard_solid(Vector3(14.0, 12.0, 16.0), Vector3(102.0, 12.9, hull_z), M.CONTAINER_GREY)
	for f in 4:
		box(Vector3(13.0, 1.1, 15.0), Vector3(102.0, 9.6 + float(f) * 2.6, hull_z), M.GLASS)
	# Stowed containers in the holds, two bays deep.
	var colors := [M.CONTAINER_BLUE, M.CONTAINER_GREEN, M.CONTAINER_GREY, M.CONTAINER_RED]
	for bay in 5:
		for tier in 2:
			for row in 3:
				var idx := (bay * 5 + tier * 3 + row) % colors.size()
				hazard_solid(Vector3(12.0, 2.6, 2.44),
					Vector3(10.0 + float(bay) * 13.0, 8.2 + float(tier) * 2.7,
						hull_z - 3.0 + float(row) * 2.6),
					colors[idx])
	billboard("MV GELDERLAND", Vector3(102.0, 20.0, hull_z - 8.2), Color(0.9, 0.9, 0.95), 34)


## The yard stack the gantry feeds. Also the visual scale reference: nothing
## says "this crane is enormous" like a five-high block of boxes under it.
func _stacks() -> void:
	for block in 4:
		var x := 4.0 + float(block) * 15.0
		container_stack(Vector3(x, 0.0, STACK_Z), 4, 3 if block % 2 == 0 else 4)
	# Reefer racks and a lashing store off to one side.
	for i in 6:
		hazard_solid(Vector3(2.4, 3.0, 2.4), Vector3(78.0, 1.5, 16.0 + float(i) * 2.8), M.STEEL_GALV)


func _lanes() -> void:
	box(Vector3(130.0, 0.02, 9.0), Vector3(40.0, 0.03, 37.0), M.ASPHALT)
	for i in 26:
		var x := -20.0 + float(i) * 5.2
		floor_line(Vector3(x, 0.0, 37.0), Vector3(x + 2.6, 0.0, 37.0), 0.16,
			Color(0.92, 0.92, 0.9, 0.8))
	# Waiting trucks with chassis.
	for i in 4:
		var x := 6.0 + float(i) * 22.0
		hazard_solid(Vector3(13.0, 1.3, 2.6), Vector3(x, 0.9, 37.0), M.STEEL_GALV)
		hazard_solid(Vector3(3.0, 2.6, 2.5), Vector3(x - 8.0, 1.6, 37.0), M.CONTAINER_BLUE)
	billboard("TRUCK LANE — KEEP LOAD CLEAR", Vector3(40.0, 4.0, 41.6),
		Color(0.98, 0.5, 0.1), 26)


## The gantry's own rails and legs are drawn by the machine visual, but the
## rails in the ground belong to the site.
func _gantry_rails() -> void:
	for z in [4.0, 20.0]:
		box(Vector3(130.0, 0.24, 0.5), Vector3(40.0, 0.12, z), M.RAIL_STEEL)
		box(Vector3(130.0, 0.1, 1.4), Vector3(40.0, 0.03, z), M.CONCRETE_DIRTY)
