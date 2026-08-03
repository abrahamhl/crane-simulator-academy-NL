extends Area3D
## LoadBody — the collision surface for the suspended load. Position always
## FOLLOWS cable_load_sim's math (the sim keeps authority over the physics);
## contact resolution is applied EXTERNALLY by main.gd, which writes a
## corrected sim.load_pos/load_vel back after each tick — the validated
## free-swing integrator in cable_load_sim.gd is never modified (DEC-009,
## DEC-014). Per .claude/rules/simulation-physics.md: "separate physical
## collision volumes from safety/near-miss volumes" — see LOAD_SAFETY_RADIUS_M
## for the larger caution zone, distinct from the exact contact box below.
##
## All contact/impact math is exposed as static pure functions, unit-tested
## in tests/module_tests.gd without a scene. Every function here that takes a
## "box_center" expects the LOAD'S VISUAL BOX CENTRE (sim.load_pos - (0,0.5,0)
## in this slice's geometry), NOT the raw cable-attachment point.

signal player_hit(push_velocity: Vector3)

const LOAD_SIZE := Vector3(1.2, 0.9, 1.2)

## Actual size of THIS load — a scenario sets it (a container is not a pallet).
## The static helpers still default to LOAD_SIZE so the original unit tests and
## any caller that does not care about size keep working unchanged.
var size := LOAD_SIZE
## Vertical offset from the cable-attachment point down to the box centre.
## Derived from `size` so a taller load hangs correctly instead of intersecting
## its own sling point.
var attach_offset := 0.5

var hits_count := 0
var violations_count := 0
var near_miss_count := 0

var _shape: CollisionShape3D


func _ready() -> void:
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	add_child(_shape)
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


## Resizes the collision box for a scenario's load. Safe before or after
## _ready(); the shape is created on demand either way.
func configure(new_size: Vector3) -> void:
	size = new_size
	attach_offset = new_size.y * 0.5 + 0.05
	if _shape != null and _shape.shape is BoxShape3D:
		_shape.shape.size = new_size


## load_pos: the sim's raw cable-attachment point (NOT the box centre — this
## applies the same offset the visual mesh uses).
func sync_to_sim(load_pos: Vector3) -> void:
	global_position = load_pos - Vector3(0.0, attach_offset, 0.0)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		hits_count += 1
		violations_count += 1
		var away := (body.global_position - global_position)
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3.FORWARD
		emit_signal("player_hit", compute_push_velocity(away.normalized()))


## Any contact between a suspended load and a person is a safety violation
## regardless of speed — standard lifting-safety doctrine ("never work under
## a suspended load"), not an energy threshold.
static func is_dangerous_impact(_load_vel: Vector3, _load_mass: float) -> bool:
	return true


## Push imparted to a struck player: outward horizontal shove, small vertical
## lift for game feel. Clamped so a slow-swinging load doesn't fling the
## player unrealistically.
static func compute_push_velocity(away_dir: Vector3) -> Vector3:
	var d := away_dir
	d.y = 0.0
	if d.length() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	return d * 3.0 + Vector3(0.0, 1.5, 0.0)


static func aabb_overlap(pos_a: Vector3, size_a: Vector3, pos_b: Vector3, size_b: Vector3) -> bool:
	var half_a := size_a * 0.5
	var half_b := size_b * 0.5
	return absf(pos_a.x - pos_b.x) <= (half_a.x + half_b.x) \
		and absf(pos_a.y - pos_b.y) <= (half_a.y + half_b.y) \
		and absf(pos_a.z - pos_b.z) <= (half_a.z + half_b.z)


## Load resting/crashing on the ground (ground top at y=0).
static func check_floor_contact(box_center: Vector3, load_size: Vector3 = LOAD_SIZE) -> bool:
	return (box_center.y - load_size.y * 0.5) <= 0.0


## Load swung into structure. `columns` is the Array of {pos, size} an
## environment builder registers as obstacles.
static func check_column_contact(box_center: Vector3, columns: Array,
		load_size: Vector3 = LOAD_SIZE) -> bool:
	for c in columns:
		if aabb_overlap(box_center, load_size, c.pos, c.size):
			return true
	return false


## True if `pos` (player position, any point on their body) is within the
## load's caution radius but NOT necessarily touching it — the near-miss
## volume from .claude/rules/simulation-physics.md, kept separate from the
## exact contact box above.
static func is_within_safety_radius(box_center: Vector3, pos: Vector3, radius: float) -> bool:
	return box_center.distance_to(pos) <= radius


## Bounces the load off the floor: clamps it to sit exactly on the surface
## and reflects the downward velocity with restitution/damping. Returns
## {hit, center, vel} — `center` is the corrected BOX CENTRE, `vel` the
## corrected load_vel; caller only needs to act when `hit` is true.
static func resolve_floor_contact(box_center: Vector3, load_vel: Vector3,
		restitution: float, damping: float, load_size: Vector3 = LOAD_SIZE) -> Dictionary:
	var floor_gap := box_center.y - load_size.y * 0.5
	if floor_gap > 0.0 or load_vel.y >= 0.0:
		return {"hit": false, "center": box_center, "vel": load_vel}
	var center := box_center
	center.y -= floor_gap  # push back up to exactly touching
	var vel := load_vel
	vel.y = -vel.y * restitution
	vel.x *= damping
	vel.z *= damping
	return {"hit": true, "center": center, "vel": vel}


## Bounces the load off the first overlapping column: pushes it out along the
## axis of least penetration and reflects that velocity component.
static func resolve_column_contact(box_center: Vector3, load_vel: Vector3,
		columns: Array, restitution: float, damping: float,
		load_size: Vector3 = LOAD_SIZE) -> Dictionary:
	var half_a := load_size * 0.5
	for c in columns:
		var half_b: Vector3 = c.size * 0.5
		var delta: Vector3 = box_center - c.pos
		if not aabb_overlap(box_center, load_size, c.pos, c.size):
			continue
		var overlap_x: float = (half_a.x + half_b.x) - absf(delta.x)
		var overlap_z: float = (half_a.z + half_b.z) - absf(delta.z)
		var center := box_center
		var vel := load_vel
		if overlap_x < overlap_z:
			var sign_x := 1.0 if delta.x >= 0.0 else -1.0
			center.x = c.pos.x + sign_x * (half_a.x + half_b.x)
			vel.x = -vel.x * restitution
			vel.z *= damping
		else:
			var sign_z := 1.0 if delta.z >= 0.0 else -1.0
			center.z = c.pos.z + sign_z * (half_a.z + half_b.z)
			vel.z = -vel.z * restitution
			vel.x *= damping
		return {"hit": true, "center": center, "vel": vel}
	return {"hit": false, "center": box_center, "vel": load_vel}
