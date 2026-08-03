extends "res://environments/env_base.gd"
## Production hall, Arnhem — the indoor site for the pendant-operated bridge
## cranes. Sheltered, so wind is a draught rather than a force, but every
## column, rack and stack is something to swing a load into.
##
## Layout runs along +X (the bridge's travel direction), 64 m by 22 m, with
## the crane runway at 8.85 m and a 9.0 m rail height matching MC-OVH-*'s
## geometry.head_height. The control position sits at x=1.0, deliberately
## OUTSIDE the bridge's own travel limit (2.0 m) so the operator is provably
## never underneath the machine they are driving.

const HALF_X := 32.0
const HALF_Z := 11.0
const CENTER := Vector3(30.0, 0.0, 9.0)
const ROOF_H := 11.5


func build(_ctx: Dictionary) -> void:
	machine_base = Vector3.ZERO
	player_spawn = Vector3(10.0, 0.2, 14.0)

	ground(Vector2(HALF_X * 2.0, HALF_Z * 2.0), Vector2(CENTER.x, CENTER.z), M.CONCRETE)
	boundary_walls(8.0)
	_shell()
	_columns_and_runway()
	_markings()
	_racking()
	_props()

	control_station(Vector3(1.0, 0.0, 9.0), "pendant")
	_high_bay_lights()

	# The marked pedestrian walkway. Carrying a load across it is the indoor
	# equivalent of swinging over a public pavement, and it is the one route
	# through the hall a person on foot is entitled to assume is safe.
	hazard_zone(Rect2(-2.0, 2.9, 64.0, 1.6), "violation_public",
		Color(0.95, 0.25, 0.15, 0.12))


## Walls and roof. Corrugated cladding outside, a lighter band of translucent
## roof panels down the centre so the hall reads as daylit rather than a box.
func _shell() -> void:
	var wall := M.CORRUGATED
	solid(Vector3(HALF_X * 2.0, ROOF_H, 0.35), CENTER + Vector3(0.0, ROOF_H * 0.5, -HALF_Z), wall)
	solid(Vector3(HALF_X * 2.0, ROOF_H, 0.35), CENTER + Vector3(0.0, ROOF_H * 0.5, HALF_Z), wall)
	solid(Vector3(0.35, ROOF_H, HALF_Z * 2.0), CENTER + Vector3(-HALF_X, ROOF_H * 0.5, 0.0), wall)
	# East gable has the roller door: a bright opening that gives the hall a
	# direction and a visible "outside".
	solid(Vector3(0.35, ROOF_H, HALF_Z * 2.0 - 8.0), CENTER + Vector3(HALF_X, ROOF_H * 0.5, -4.0), wall)
	box(Vector3(0.30, 6.0, 8.0), CENTER + Vector3(HALF_X, 3.0, 6.0), M.STEEL_PAINTED)
	box(Vector3(0.10, 5.4, 7.4), CENTER + Vector3(HALF_X - 0.2, 2.7, 6.0), M.HAZARD_STRIPE)

	box(Vector3(HALF_X * 2.0, 0.4, HALF_Z * 2.0), CENTER + Vector3(0.0, ROOF_H, 0.0), M.STEEL_GALV)
	box(Vector3(HALF_X * 2.0 - 2.0, 0.08, 4.0), CENTER + Vector3(0.0, ROOF_H - 0.25, 0.0),
		M.GLASS)
	# Roof trusses, purely visual but they give the ceiling depth.
	for i in 13:
		var x := 2.0 + float(i) * 5.0
		box(Vector3(0.25, 0.25, HALF_Z * 2.0 - 1.0), Vector3(x, ROOF_H - 0.55, CENTER.z), M.STEEL_GALV)


func _columns_and_runway() -> void:
	for xi in 8:
		var x := 2.0 + float(xi) * 8.0
		for z in [0.75, 17.25]:
			var pos := Vector3(x, 4.35, z)
			hazard_solid(Vector3(0.4, 8.7, 0.4), pos, M.STEEL_PAINTED)
			box(Vector3(0.9, 0.12, 0.9), Vector3(x, 0.06, z), M.CONCRETE_DIRTY)
			# Impact-protection collar: a real hall marks the base of every
			# column, and it is the cue a learner should be reading.
			box(Vector3(0.55, 1.2, 0.55), Vector3(x, 0.6, z), M.HAZARD_STRIPE)

	box(Vector3(60.0, 0.35, 0.35), Vector3(30.0, 8.85, 0.75), M.RAIL_STEEL)
	box(Vector3(60.0, 0.35, 0.35), Vector3(30.0, 8.85, 17.25), M.RAIL_STEEL)
	box(Vector3(60.0, 0.6, 0.5), Vector3(30.0, 8.45, 0.75), M.STEEL_PAINTED)
	box(Vector3(60.0, 0.6, 0.5), Vector3(30.0, 8.45, 17.25), M.STEEL_PAINTED)


func _markings() -> void:
	var yellow := Color(0.95, 0.82, 0.10, 0.95)
	var white := Color(0.90, 0.90, 0.92, 0.85)
	# Pedestrian walkway down the south side — the route the operator should
	# actually use to reach the control station.
	floor_line(Vector3(-1.0, 0.0, 3.0), Vector3(61.0, 0.0, 3.0), 0.12, yellow)
	floor_line(Vector3(-1.0, 0.0, 4.4), Vector3(61.0, 0.0, 4.4), 0.12, yellow)
	for i in 30:
		var x := -1.0 + float(i) * 2.1
		floor_line(Vector3(x, 0.0, 3.05), Vector3(x + 0.9, 0.0, 4.35), 0.06, Color(0.95, 0.82, 0.10, 0.35))
	# Bay grid, so distance along the hall is readable at a glance.
	for i in 8:
		var x := 2.0 + float(i) * 8.0
		floor_line(Vector3(x, 0.0, 5.5), Vector3(x, 0.0, 16.5), 0.08, white)
		billboard("%d m" % int(x), Vector3(x, 0.6, 5.2), Color(0.85, 0.87, 0.9), 16)


func _racking() -> void:
	# Pallet racking along the north wall: tall, hittable, and a realistic
	# reason for the bridge to have a restricted approach on that side.
	for bay in 6:
		var x := 6.0 + float(bay) * 9.0
		for lvl in 3:
			var y := 0.9 + float(lvl) * 1.7
			hazard_solid(Vector3(7.6, 0.12, 1.1), Vector3(x, y, 16.0), M.STEEL_RUSTY)
		for side in [-3.8, 3.8]:
			hazard_solid(Vector3(0.16, 5.4, 1.1), Vector3(x + side, 2.7, 16.0), M.STEEL_PAINTED)
		if bay % 2 == 0:
			solid(Vector3(1.2, 0.9, 0.9), Vector3(x - 2.0, 1.45, 16.0), M.WOOD_PALLET)
			solid(Vector3(1.2, 0.9, 0.9), Vector3(x + 2.0, 3.15, 16.0), M.WOOD_PALLET)


## High-bay lamps down both sides of the hall. Unlike outdoor worklights these
## are ALWAYS on, not weather-gated: an indoor bay is lit whatever the sky is
## doing, and they are what actually models the floor now that the roof no
## longer lets a shadow-casting sun through.
func _high_bay_lights() -> void:
	var p: Dictionary = Weather.get_preset(weather_id)
	var night := float(p.get("visibility_m", 999.0)) < 200.0 or bool(p.get("needs_worklights", false))
	for i in 6:
		var x := 6.0 + float(i) * 10.0
		for z in [4.5, 13.5]:
			var pos := Vector3(x, 10.2, z)
			var lamp := OmniLight3D.new()
			lamp.position = pos
			lamp.light_energy = 5.5 if night else 3.2
			lamp.omni_range = 22.0
			lamp.light_color = Color(1.0, 0.96, 0.88)
			lamp.shadow_enabled = false
			add_child(lamp)
			box(Vector3(0.7, 0.18, 0.5), pos + Vector3(0.0, 0.16, 0.0), M.STEEL_GALV)
			box(Vector3(0.55, 0.04, 0.36), pos + Vector3(0.0, 0.04, 0.0), M.HIVIS)


func _props() -> void:
	# Steel stock stacked on the floor: the obstacles a load is most likely to
	# be swung into, and they read instantly as "heavy, do not touch".
	for i in 3:
		var x := 16.0 + float(i) * 13.0
		hazard_solid(Vector3(5.0, 0.9, 1.4), Vector3(x, 0.45, 7.2), M.STEEL_RAW)
		hazard_solid(Vector3(4.4, 0.7, 1.2), Vector3(x, 1.25, 7.2), M.STEEL_RUSTY)
	# Workbenches and a tool wall on the south side, out of the crane's path.
	for i in 4:
		var x := 8.0 + float(i) * 12.0
		solid(Vector3(2.4, 0.9, 0.8), Vector3(x, 0.45, 1.6), M.STEEL_GALV)
		box(Vector3(2.2, 1.3, 0.06), Vector3(x, 1.9, 1.2), M.STEEL_PAINTED)
	# Waste skips near the door.
	hazard_solid(Vector3(2.6, 1.3, 1.8), Vector3(56.0, 0.65, 13.0), M.STEEL_RUSTY)
	hazard_solid(Vector3(2.6, 1.3, 1.8), Vector3(56.0, 0.65, 15.5), M.CRANE_YELLOW)

	billboard("GELDERLAND OPERATOR ACADEMY", Vector3(30.0, 9.8, 0.4),
		Color(0.55, 0.75, 0.95), 40)
