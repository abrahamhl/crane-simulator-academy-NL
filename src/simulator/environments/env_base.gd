extends Node3D
## EnvBase — shared construction kit for every site.
##
## Concrete environments subclass this and implement `build()`. Everything a
## site must hand back to the session is declared here, so the session never
## needs to know which site it is running:
##
##   obstacles         [{pos, size}] world-space boxes the LOAD can strike
##   control_position  where the operator takes the controls
##   control_kind      "pendant" | "cabin" | "ground" — changes the prompt,
##                     the camera and whether the operator can walk away
##   machine_base      the machine's footprint origin
##   player_spawn      where the operator starts on foot
##   hazard_zones      [{rect: Rect2 (x,z), key, deadly}] scored areas the load
##                     must not be carried over
##   worklight_points  positions for night lighting
##
## Geometry helpers all take a MaterialLibrary id, never a raw Color, so a
## site cannot accidentally introduce an unshaded programmer-art surface.

const M := preload("res://core/materials.gd")

var obstacles: Array = []
var hazard_zones: Array = []
var worklight_points: Array = []
var control_position := Vector3(0.0, 0.0, 0.0)
var control_kind := "pendant"
var machine_base := Vector3.ZERO
var player_spawn := Vector3(0.0, 0.1, 0.0)
var ground_half := Vector2(30.0, 30.0)
var ground_center := Vector2.ZERO

var weather_id := "clear"
var env_id := ""

var _static_root: Node3D


func _ready() -> void:
	_static_root = Node3D.new()
	_static_root.name = "Static"
	add_child(_static_root)


## Subclasses override. `ctx` carries the weather id and the scenario, so a
## site can react (snow cover, worklights, scenario-specific props).
func build(_ctx: Dictionary) -> void:
	pass


# --- geometry helpers ---------------------------------------------------------

## Visual box only. Use for anything the load cannot hit.
func box(size: Vector3, pos: Vector3, mat_id: String, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = MaterialLibrary.get_mat(mat_id)
	mi.position = pos
	if absf(rot_y_deg) > 0.001:
		mi.rotation_degrees.y = rot_y_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


## Visual box + a StaticBody3D the PLAYER collides with. Use for walls, kerbs,
## anything a person can walk into.
func solid(size: Vector3, pos: Vector3, mat_id: String, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var mi := box(size, pos, mat_id, rot_y_deg)
	_collider(size, pos, rot_y_deg)
	return mi


## Visual box + player collider + registered as a LOAD obstacle, so swinging
## the load into it counts as a strike. This is the one to use for columns,
## stacks, parked vehicles and building edges.
func hazard_solid(size: Vector3, pos: Vector3, mat_id: String, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var mi := solid(size, pos, mat_id, rot_y_deg)
	obstacles.append({"pos": pos, "size": size})
	return mi


## Registers an obstacle for the load WITHOUT geometry — for the invisible
## envelope around something modelled with many small pieces (a scaffold, a
## vehicle) where one box is the honest collision proxy.
func obstacle_only(size: Vector3, pos: Vector3) -> void:
	obstacles.append({"pos": pos, "size": size})


func _collider(size: Vector3, pos: Vector3, rot_y_deg: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	if absf(rot_y_deg) > 0.001:
		body.rotation_degrees.y = rot_y_deg
	var shape := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	shape.shape = s
	body.add_child(shape)
	if _static_root != null:
		_static_root.add_child(body)
	else:
		add_child(body)


## Flat ground plate with a real collider, sized from the environment spec.
func ground(size: Vector2, center: Vector2, mat_id: String) -> void:
	ground_half = size * 0.5
	ground_center = center
	var pos := Vector3(center.x, -0.10, center.y)
	box(Vector3(size.x, 0.2, size.y), pos, mat_id)
	_collider(Vector3(size.x, 0.2, size.y), pos)


## Invisible perimeter so a player with real gravity cannot walk off the world.
func boundary_walls(height: float = 6.0) -> void:
	var t := 0.6
	var c := ground_center
	var h := ground_half
	_collider(Vector3(t, height, h.y * 2.0), Vector3(c.x - h.x, height * 0.5, c.y))
	_collider(Vector3(t, height, h.y * 2.0), Vector3(c.x + h.x, height * 0.5, c.y))
	_collider(Vector3(h.x * 2.0, height, t), Vector3(c.x, height * 0.5, c.y - h.y))
	_collider(Vector3(h.x * 2.0, height, t), Vector3(c.x, height * 0.5, c.y + h.y))


## Painted floor line — the marking that tells a person where it is safe to
## walk. Unshaded so it stays legible in fog and at night.
func floor_line(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var d := to - from
	var length := Vector2(d.x, d.z).length()
	if length < 0.01:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.01, width)
	mi.mesh = mesh
	mi.material_override = MaterialLibrary.unshaded(color)
	mi.position = (from + to) * 0.5 + Vector3(0.0, 0.012, 0.0)
	mi.rotation.y = -atan2(d.z, d.x)
	add_child(mi)


## Floor disc marking a zone (pick-up, set-down, control position).
func floor_disc(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	mi.mesh = cyl
	mi.material_override = MaterialLibrary.unshaded(color)
	mi.position = pos + Vector3(0.0, 0.015, 0.0)
	add_child(mi)
	return mi


## Vertical light beam so a zone is findable from across a 100 m site — the
## single fix for "no sé hacia dónde está mapeado".
func zone_beacon(pos: Vector3, color: Color, height: float = 14.0) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.10
	cyl.bottom_radius = 0.28
	cyl.height = height
	mi.mesh = cyl
	mi.material_override = MaterialLibrary.unshaded(Color(color.r, color.g, color.b, 0.22))
	mi.position = pos + Vector3(0.0, height * 0.5, 0.0)
	add_child(mi)


func billboard(text: String, pos: Vector3, color: Color, font_size: int = 30) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.no_depth_test = false
	label.fixed_size = false
	add_child(label)
	return label


## Hazard area the load must not be carried over. `rect` is in world XZ.
##
## `y_min`/`y_max` bound the HEIGHT band in which the rule applies, and they
## matter: carrying a load over a live traffic lane is a violation at any
## height above the ground, but approaching an overhead line is only a
## violation near the wire. Without the band, every wire zone would also
## forbid working at ground level underneath it, which is the opposite of the
## real rule.
func hazard_zone(rect: Rect2, key: String, mark_color: Color = Color(0.9, 0.2, 0.2, 0.16),
		y_min: float = 0.05, y_max: float = 1000.0) -> void:
	hazard_zones.append({"rect": rect, "key": key, "y_min": y_min, "y_max": y_max})
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x, 0.01, rect.size.y)
	mi.mesh = mesh
	mi.material_override = MaterialLibrary.unshaded(mark_color)
	mi.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.02,
		rect.position.y + rect.size.y * 0.5)
	add_child(mi)


## Site worklight — a real OmniLight, added only when the weather needs it so
## a clear midday scene does not pay for eight shadow-casting lights.
func worklight(pos: Vector3, energy: float = 3.0, range_m: float = 26.0) -> void:
	worklight_points.append(pos)
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.omni_range = range_m
	l.light_color = Color(1.0, 0.94, 0.82)
	l.shadow_enabled = false
	add_child(l)
	box(Vector3(0.5, 0.16, 0.3), pos + Vector3(0.0, 0.12, 0.0), M.STEEL_GALV)


## Adds worklights only under a preset that calls for them.
func maybe_worklights(points: Array) -> void:
	var p: Dictionary = Weather.get_preset(weather_id)
	if not bool(p.get("needs_worklights", false)) and float(p.get("visibility_m", 999.0)) > 200.0:
		return
	for pt in points:
		worklight(pt)


## Ground material swap for snow cover — one line in each site instead of a
## snow branch in every surface.
func ground_material_for(base_id: String) -> String:
	if bool(Weather.get_preset(weather_id).get("snow_cover", false)):
		return M.SNOW
	return base_id


# --- reusable props -----------------------------------------------------------

## A stack of shipping containers. Returns the top surface height so a
## scenario can place a set-down target on it.
func container_stack(origin: Vector3, cols: int, rows: int, yaw_deg: float = 0.0) -> float:
	var colors := [M.CONTAINER_BLUE, M.CONTAINER_RED, M.CONTAINER_GREEN, M.CONTAINER_GREY]
	var size := Vector3(12.0, 2.6, 2.44)
	for r in rows:
		for c in cols:
			var idx := (r * 7 + c * 3) % colors.size()
			var pos := origin + Vector3(0.0, size.y * (0.5 + r), size.z * 1.05 * c)
			hazard_solid(size, pos, colors[idx], yaw_deg)
	return origin.y + size.y * rows


## Euro-pallet with stacked blocks — the generic "load" prop.
func pallet_stack(pos: Vector3, layers: int = 2) -> void:
	solid(Vector3(1.2, 0.14, 0.8), pos + Vector3(0.0, 0.07, 0.0), M.WOOD_PALLET)
	for i in layers:
		solid(Vector3(1.05, 0.30, 0.7), pos + Vector3(0.0, 0.14 + 0.30 * (i + 0.5), 0.0), M.CONCRETE)


## Safety barrier run along X or Z — red/white posts with a rail.
func barrier_run(from: Vector3, to: Vector3) -> void:
	var d := to - from
	var length := Vector2(d.x, d.z).length()
	if length < 0.5:
		return
	var n := maxi(2, int(length / 2.5))
	for i in n + 1:
		var p := from.lerp(to, float(i) / float(n))
		box(Vector3(0.08, 1.1, 0.08), p + Vector3(0.0, 0.55, 0.0), M.HAZARD_STRIPE)
	var mid := (from + to) * 0.5
	var rail := box(Vector3(length, 0.10, 0.06), mid + Vector3(0.0, 0.95, 0.0), M.HAZARD_STRIPE)
	rail.rotation.y = -atan2(d.z, d.x)


## The physical control station the operator walks to. Drawn differently per
## kind so the player can SEE what they are approaching before reading a
## prompt: a pendant on a post, a cab with a ladder, or a ground stand.
func control_station(pos: Vector3, kind: String) -> void:
	control_position = pos
	control_kind = kind
	match kind:
		"cabin":
			box(Vector3(0.10, 3.6, 0.10), pos + Vector3(-0.5, 1.8, 0.0), M.STEEL_GALV)
			box(Vector3(0.10, 3.6, 0.10), pos + Vector3(0.5, 1.8, 0.0), M.STEEL_GALV)
			for i in 9:
				box(Vector3(1.0, 0.05, 0.16), pos + Vector3(0.0, 0.4 * (i + 1), 0.0), M.STEEL_GALV)
			billboard(Loc.t("access_cabin"), pos + Vector3(0.0, 2.4, 0.0), Color(1.0, 0.75, 0.1), 26)
		"ground":
			box(Vector3(0.9, 0.10, 0.7), pos + Vector3(0.0, 0.05, 0.0), M.STEEL_GALV)
			box(Vector3(0.12, 1.0, 0.12), pos + Vector3(0.0, 0.55, 0.0), M.STEEL_PAINTED)
			box(Vector3(0.55, 0.40, 0.22), pos + Vector3(0.0, 1.20, 0.05), M.CRANE_ORANGE)
			box(Vector3(0.10, 0.06, 0.06), pos + Vector3(-0.14, 1.36, 0.15), M.HIVIS)
			box(Vector3(0.10, 0.06, 0.06), pos + Vector3(0.14, 1.36, 0.15), M.CRANE_RED)
			billboard(Loc.t("access_ground"), pos + Vector3(0.0, 2.0, 0.0), Color(1.0, 0.62, 0.06), 24)
		_:
			box(Vector3(0.12, 1.15, 0.12), pos + Vector3(0.0, 0.57, 0.0), M.STEEL_PAINTED)
			box(Vector3(0.34, 0.46, 0.18), pos + Vector3(0.0, 1.18, 0.08), M.CRANE_ORANGE)
			box(Vector3(0.08, 0.05, 0.05), pos + Vector3(-0.09, 1.32, 0.17), M.HIVIS)
			box(Vector3(0.08, 0.05, 0.05), pos + Vector3(0.09, 1.32, 0.17), M.CRANE_RED)
			billboard(Loc.t("access_pendant"), pos + Vector3(0.0, 1.9, 0.0), Color(1.0, 0.62, 0.06), 24)
	floor_disc(pos, AppSettings.ACCESS_RADIUS_M, Color(0.95, 0.55, 0.05, 0.30))
