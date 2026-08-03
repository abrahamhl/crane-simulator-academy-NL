extends Node3D
## MachineVisual — builds and animates the crane you can see, driven entirely
## by MachineRig's axis state. One class per machine family; the session never
## touches these nodes directly, it just calls `sync(rig)` each frame.
##
## Geometry is deliberately built from primitives with real materials rather
## than imported models: it keeps the project offline and license-clean, and a
## lattice boom made of actual chords and diagonals reads as a lattice boom.
## Nothing here affects physics — the rope head comes from rig.support_point()
## and this file's job is to put steel where that point implies it must be.

const M := preload("res://core/materials.gd")

var spec: Dictionary = {}
var rig: RefCounted

# Nodes that move. Which ones exist depends on the machine class.
var slew_pivot: Node3D          # rotates with slew
var boom: Node3D                # luffs; child of slew_pivot
var boom_sections: Array = []   # telescoping sections
var bridge: Node3D              # overhead/gantry bridge girder assembly
var trolley: Node3D
var rope: MeshInstance3D
var hook_block: Node3D
var spreader: Node3D
var outrigger_beams: Array = []
var outrigger_pads: Array = []
var cabin_anchor: Node3D        # where the "operator's eye" camera sits


func setup(p_spec: Dictionary, p_rig: RefCounted, base: Vector3) -> void:
	spec = p_spec
	rig = p_rig
	position = base
	match String(spec.get("class", MachineCatalog.CLASS_OVERHEAD)):
		MachineCatalog.CLASS_TOWER: _build_tower()
		MachineCatalog.CLASS_GANTRY: _build_gantry()
		MachineCatalog.CLASS_MOBILE: _build_mobile()
		MachineCatalog.CLASS_LOADER: _build_loader()
		MachineCatalog.CLASS_RAILWAY: _build_railway()
		_: _build_overhead()
	_build_rope_and_hook()


# --- helpers -----------------------------------------------------------------

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat_id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = MaterialLibrary.get_mat(mat_id)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat_id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = MaterialLibrary.get_mat(mat_id)
	mi.position = pos
	parent.add_child(mi)
	return mi


## A lattice section along local +X: four chords plus zig-zag bracing. This is
## the single most recognisable "crane" shape and it costs almost nothing.
func _lattice(parent: Node3D, length: float, width: float, mat_id: String) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var h := width * 0.5
	for oy in [-h, h]:
		for oz in [-h, h]:
			_box(root, Vector3(length, 0.10, 0.10), Vector3(length * 0.5, oy, oz), mat_id)
	var bays := maxi(3, int(length / (width * 1.15)))
	for i in bays:
		var x0 := length * float(i) / float(bays)
		var x1 := length * float(i + 1) / float(bays)
		for oz in [-h, h]:
			var d := Vector3(x1 - x0, width, 0.0)
			var mi := _box(root, Vector3(d.length(), 0.07, 0.07),
				Vector3((x0 + x1) * 0.5, 0.0, oz), mat_id)
			mi.rotation.z = atan2(d.y, d.x) * (1.0 if i % 2 == 0 else -1.0)
		for oy in [-h, h]:
			var d2 := Vector3(x1 - x0, 0.0, width)
			var mi2 := _box(root, Vector3(d2.length(), 0.07, 0.07),
				Vector3((x0 + x1) * 0.5, oy, 0.0), mat_id)
			mi2.rotation.y = -atan2(d2.z, d2.x) * (1.0 if i % 2 == 0 else -1.0)
	return root


func _make_cabin(parent: Node3D, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var c := Node3D.new()
	c.position = pos
	c.rotation_degrees.y = yaw_deg
	parent.add_child(c)
	_box(c, Vector3(2.0, 2.0, 1.8), Vector3.ZERO, M.CRANE_YELLOW)
	_box(c, Vector3(1.75, 1.15, 0.06), Vector3(0.0, 0.25, -0.92), M.GLASS)
	_box(c, Vector3(0.06, 1.15, 1.6), Vector3(-1.0, 0.25, 0.0), M.GLASS)
	_box(c, Vector3(0.06, 1.15, 1.6), Vector3(1.0, 0.25, 0.0), M.GLASS)
	_box(c, Vector3(1.75, 0.9, 0.06), Vector3(0.0, -0.5, -0.92), M.GLASS)   # floor window
	cabin_anchor = Node3D.new()
	cabin_anchor.position = Vector3(0.0, 0.35, -0.35)
	c.add_child(cabin_anchor)
	return c


func _make_outriggers(half: Vector2) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var beam := Node3D.new()
			add_child(beam)
			var arm := _box(beam, Vector3(half.x, 0.32, 0.32),
				Vector3(sx * half.x * 0.5, 0.9, sz * half.y), M.CRANE_YELLOW)
			var pad := _cyl(beam, 0.55, 0.18, Vector3(sx * half.x, 0.09, sz * half.y),
				M.STEEL_GALV)
			var leg := _box(beam, Vector3(0.26, 0.9, 0.26),
				Vector3(sx * half.x, 0.45, sz * half.y), M.STEEL_GALV)
			outrigger_beams.append({"arm": arm, "leg": leg, "sx": sx, "sz": sz, "half": half})
			outrigger_pads.append(pad)


# --- overhead / gantry --------------------------------------------------------

func _build_overhead() -> void:
	var g: Dictionary = spec.get("geometry", {})
	var head: float = float(g.get("head_height", 9.0))
	var a: Dictionary = spec.axes
	var span: float = float(a.trolley.max) + 1.5

	bridge = Node3D.new()
	add_child(bridge)
	# Twin box girders + end carriages: what a real bovenloopkraan looks like.
	for oz in [-0.55, 0.55]:
		_box(bridge, Vector3(0.55, 0.95, span + 2.0), Vector3(0.0, head + 0.35, span * 0.5 + oz),
			M.CRANE_YELLOW)
	_box(bridge, Vector3(1.9, 0.30, span + 2.0), Vector3(0.0, head + 0.88, span * 0.5), M.STEEL_PAINTED)
	for z in [0.75, float(a.trolley.max) + 1.0]:
		_box(bridge, Vector3(1.6, 0.45, 0.8), Vector3(0.0, head - 0.15, z), M.STEEL_PAINTED)
		for wx in [-0.55, 0.55]:
			_cyl(bridge, 0.28, 0.16, Vector3(wx, head - 0.42, z), M.RAIL_STEEL).rotation.z = PI / 2.0
	# Festoon cable track along the girder.
	_box(bridge, Vector3(0.10, 0.10, span), Vector3(0.9, head + 0.55, span * 0.5), M.CABLE)

	trolley = Node3D.new()
	bridge.add_child(trolley)
	_box(trolley, Vector3(1.5, 0.65, 1.4), Vector3(0.0, head - 0.45, 0.0), M.CRANE_ORANGE)
	_box(trolley, Vector3(0.85, 0.55, 0.85), Vector3(0.0, head - 0.05, 0.0), M.STEEL_PAINTED)
	_cyl(trolley, 0.30, 1.1, Vector3(0.0, head - 0.05, 0.0), M.STEEL_RAW).rotation.z = PI / 2.0


func _build_gantry() -> void:
	var g: Dictionary = spec.get("geometry", {})
	var head: float = float(g.get("head_height", 38.0))
	var a: Dictionary = spec.axes
	var reach: float = float(a.trolley.max) + 4.0

	bridge = Node3D.new()
	add_child(bridge)
	# Portal legs straddling the quay rails at z = 4 and z = 20.
	for lz in [4.0, 20.0]:
		for lx in [-5.0, 5.0]:
			_box(bridge, Vector3(1.4, head, 1.4), Vector3(lx, head * 0.5, lz), M.CRANE_ORANGE)
			_box(bridge, Vector3(3.2, 1.2, 3.2), Vector3(lx, 0.7, lz), M.STEEL_PAINTED)
		_box(bridge, Vector3(12.6, 1.6, 1.8), Vector3(0.0, head - 1.0, lz), M.CRANE_ORANGE)
	# Boom over the water plus the backreach over the yard.
	_box(bridge, Vector3(3.0, 2.2, reach + 24.0), Vector3(0.0, head + 1.6, reach * 0.5 - 8.0),
		M.CRANE_ORANGE)
	_box(bridge, Vector3(2.2, 0.5, reach + 24.0), Vector3(0.0, head + 2.9, reach * 0.5 - 8.0),
		M.STEEL_PAINTED)
	# A-frame and stays.
	_box(bridge, Vector3(1.0, 14.0, 1.0), Vector3(0.0, head + 8.5, 12.0), M.STEEL_PAINTED)
	for tz in [-6.0, reach + 8.0]:
		var d := Vector3(0.0, -14.0, tz - 12.0)
		var mi := _box(bridge, Vector3(0.5, 0.5, d.length()), Vector3(0.0, head + 8.5, (12.0 + tz) * 0.5),
			M.CABLE)
		mi.rotation.x = atan2(d.y, d.z)
	_make_cabin(bridge, Vector3(3.4, head - 2.0, 12.0), 180.0)

	trolley = Node3D.new()
	bridge.add_child(trolley)
	_box(trolley, Vector3(2.6, 1.4, 3.4), Vector3(0.0, head + 0.2, 0.0), M.CRANE_YELLOW)
	_box(trolley, Vector3(1.6, 0.8, 1.6), Vector3(0.0, head - 0.8, 0.0), M.STEEL_PAINTED)


# --- tower --------------------------------------------------------------------

func _build_tower() -> void:
	var g: Dictionary = spec.get("geometry", {})
	var head: float = float(g.get("head_height", 42.0))
	var a: Dictionary = spec.axes
	var jib: float = float(a.trolley.max) + 2.0

	# Base and mast: stacked lattice sections up to the slew ring.
	_box(self, Vector3(6.0, 1.2, 6.0), Vector3(0.0, 0.6, 0.0), M.CONCRETE)
	for i in int(head / 3.0):
		var y := 1.2 + float(i) * 3.0
		for ox in [-0.85, 0.85]:
			for oz in [-0.85, 0.85]:
				_box(self, Vector3(0.16, 3.0, 0.16), Vector3(ox, y + 1.5, oz), M.CRANE_YELLOW)
		for oz2 in [-0.85, 0.85]:
			var mi := _box(self, Vector3(0.09, 0.09, 2.4), Vector3(0.0, y + 1.5, oz2), M.CRANE_YELLOW)
			mi.rotation.x = deg_to_rad(38.0 if i % 2 == 0 else -38.0)
		if i % 4 == 0:
			for ox2 in [-0.85, 0.85]:
				_box(self, Vector3(0.10, 0.10, 1.8), Vector3(ox2, y, 0.0), M.CRANE_YELLOW)

	slew_pivot = Node3D.new()
	slew_pivot.position = Vector3(0.0, head, 0.0)
	add_child(slew_pivot)
	_box(slew_pivot, Vector3(2.4, 1.2, 2.4), Vector3.ZERO, M.STEEL_PAINTED)

	# Saddle jib along local +X, counter-jib with ballast behind.
	var jib_root := _lattice(slew_pivot, jib, 1.7, M.CRANE_YELLOW)
	jib_root.position = Vector3(1.2, 0.6, 0.0)
	var cj := _lattice(slew_pivot, 13.0, 1.6, M.CRANE_YELLOW)
	cj.position = Vector3(-1.2, 0.6, 0.0)
	cj.rotation.y = PI
	for i in 3:
		_box(slew_pivot, Vector3(1.6, 1.0, 2.6), Vector3(-12.0 - float(i) * 1.7, 0.6, 0.0), M.CONCRETE)
	# A-frame and the tie bars that make a flat-top read as a tower crane.
	_box(slew_pivot, Vector3(0.5, 6.5, 0.5), Vector3(0.0, 3.9, 0.0), M.STEEL_PAINTED)
	for tip in [jib, -13.0]:
		var d := Vector3(tip, -6.5, 0.0)
		var tie := _box(slew_pivot, Vector3(d.length(), 0.14, 0.14), Vector3(tip * 0.5, 3.9, 0.0),
			M.CABLE)
		tie.rotation.z = atan2(d.y, d.x)
	_make_cabin(slew_pivot, Vector3(2.6, -1.2, 2.0), -90.0)

	trolley = Node3D.new()
	slew_pivot.add_child(trolley)
	_box(trolley, Vector3(1.2, 0.5, 1.4), Vector3(0.0, 0.0, 0.0), M.CRANE_ORANGE)


# --- boom machines -------------------------------------------------------------

func _build_mobile() -> void:
	var g: Dictionary = spec.get("geometry", {})
	var pivot_h: float = float(g.get("pivot_height", 2.6))

	# Carrier: chassis, eight wheels, driving cab at the front.
	_box(self, Vector3(13.5, 1.0, 3.0), Vector3(0.0, 1.1, 0.0), M.CRANE_YELLOW)
	_box(self, Vector3(13.8, 0.35, 3.2), Vector3(0.0, 1.68, 0.0), M.STEEL_PAINTED)
	for i in 4:
		var wx := -5.4 + float(i) * 3.2
		for wz in [-1.55, 1.55]:
			_cyl(self, 0.68, 0.5, Vector3(wx, 0.68, wz), M.RUBBER).rotation.x = PI / 2.0
	_box(self, Vector3(2.6, 1.7, 2.7), Vector3(-5.2, 2.45, 0.0), M.CRANE_YELLOW)
	_box(self, Vector3(0.08, 1.0, 2.4), Vector3(-6.5, 2.6, 0.0), M.GLASS)
	_make_outriggers(Vector2(float(g.get("outrigger_half_x", 3.6)), 3.4))

	slew_pivot = Node3D.new()
	slew_pivot.position = Vector3(1.0, 1.9, 0.0)
	add_child(slew_pivot)
	# Superstructure: counterweight behind, operator cab beside the boom foot.
	_box(slew_pivot, Vector3(5.2, 1.8, 2.8), Vector3(-1.2, 0.9, 0.0), M.CRANE_YELLOW)
	for i in 3:
		_box(slew_pivot, Vector3(1.0, 1.6, 2.6), Vector3(-3.6 - float(i) * 1.05, 1.0, 0.0), M.CONCRETE)
	_make_cabin(slew_pivot, Vector3(0.4, 1.9, -2.0), 0.0)

	boom = Node3D.new()
	boom.position = Vector3(0.0, pivot_h - 1.9 + 1.0, 0.0)
	slew_pivot.add_child(boom)
	_build_telescope_sections(4, 1.05, 0.85)
	# Luffing rams from the superstructure to the boom foot.
	_cyl(slew_pivot, 0.20, 2.4, Vector3(0.6, 1.3, 0.0), M.STEEL_RAW).rotation.z = deg_to_rad(-35.0)


func _build_loader() -> void:
	var g: Dictionary = spec.get("geometry", {})
	var pivot_h: float = float(g.get("pivot_height", 2.1))

	# The crane sits on the lorry the street site already draws; here we add
	# only the crane's own column, base and stabiliser beams.
	_box(self, Vector3(2.6, 0.5, 2.5), Vector3(0.0, 1.35, 0.0), M.CRANE_RED)
	_make_outriggers(Vector2(2.6, 1.8))

	slew_pivot = Node3D.new()
	slew_pivot.position = Vector3(0.0, 1.6, 0.0)
	add_child(slew_pivot)
	_box(slew_pivot, Vector3(0.9, 1.4, 0.9), Vector3(0.0, 0.7, 0.0), M.CRANE_RED)
	_box(slew_pivot, Vector3(0.5, 0.9, 1.5), Vector3(-0.7, 0.9, 0.0), M.STEEL_PAINTED)

	boom = Node3D.new()
	boom.position = Vector3(0.0, pivot_h - 1.6 + 0.5, 0.0)
	slew_pivot.add_child(boom)
	_build_telescope_sections(3, 0.55, 0.45)


func _build_railway() -> void:
	var g: Dictionary = spec.get("geometry", {})
	var pivot_h: float = float(g.get("pivot_height", 3.2))
	var boom_len: float = float(g.get("boom_length", 22.0))

	# Rail bogies and deck.
	_box(self, Vector3(11.0, 1.1, 3.0), Vector3(0.0, 1.5, 0.0), M.CRANE_RED)
	_box(self, Vector3(11.4, 0.3, 3.2), Vector3(0.0, 2.1, 0.0), M.STEEL_PAINTED)
	for bx in [-3.6, 3.6]:
		_box(self, Vector3(3.2, 0.5, 2.4), Vector3(bx, 0.75, 0.0), M.STEEL_RUSTY)
		for wx in [-1.1, 1.1]:
			for wz in [-0.72, 0.72]:
				_cyl(self, 0.46, 0.12, Vector3(bx + wx, 0.46, wz), M.RAIL_STEEL).rotation.x = PI / 2.0
	_make_outriggers(Vector2(2.2, 3.8))

	slew_pivot = Node3D.new()
	slew_pivot.position = Vector3(0.0, 2.3, 0.0)
	add_child(slew_pivot)
	_box(slew_pivot, Vector3(4.4, 1.8, 2.8), Vector3(-0.8, 0.9, 0.0), M.CRANE_RED)
	for i in 2:
		_box(slew_pivot, Vector3(1.1, 1.5, 2.5), Vector3(-3.0 - float(i) * 1.15, 0.95, 0.0), M.CONCRETE)
	_make_cabin(slew_pivot, Vector3(1.0, 1.9, -1.9), 0.0)

	boom = Node3D.new()
	boom.position = Vector3(0.4, pivot_h - 2.3 + 0.9, 0.0)
	slew_pivot.add_child(boom)
	# Fixed lattice boom: one section, no telescoping.
	var lat := _lattice(boom, boom_len, 1.3, M.CRANE_RED)
	boom_sections.append({"node": lat, "base_len": boom_len, "index": 0, "lattice": true})


## Telescoping boom drawn as nested boxes. Each section keeps its own base
## length so `sync` can slide them out proportionally to the telescope axis.
func _build_telescope_sections(count: int, w0: float, w1: float) -> void:
	var a: Dictionary = spec.axes
	var min_len: float = float(a.telescope.min)
	var max_len: float = float(a.telescope.max)
	for i in count:
		var t := float(i) / float(maxi(1, count - 1))
		var w: float = lerpf(w0, w1, t)
		var sec := Node3D.new()
		boom.add_child(sec)
		var seg_len := min_len / float(count) * 1.05
		var mi := _box(sec, Vector3(seg_len, w, w * 0.92), Vector3(seg_len * 0.5, 0.0, 0.0),
			M.CRANE_YELLOW if spec["class"] == MachineCatalog.CLASS_MOBILE else M.CRANE_RED)
		boom_sections.append({"node": sec, "mesh": mi, "index": i, "count": count,
			"seg_len": seg_len, "min_len": min_len, "max_len": max_len, "lattice": false})
	# Boom head sheaves.
	var head := Node3D.new()
	boom.add_child(head)
	_cyl(head, 0.26, 0.16, Vector3.ZERO, M.STEEL_RAW).rotation.x = PI / 2.0
	boom_sections.append({"node": head, "head": true})


# --- rope, hook and spreader ---------------------------------------------------

func _build_rope_and_hook() -> void:
	rope = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.028
	cyl.bottom_radius = 0.028
	cyl.height = 1.0
	rope.mesh = cyl
	rope.material_override = MaterialLibrary.get_mat(M.CABLE)
	add_child(rope)

	hook_block = Node3D.new()
	add_child(hook_block)
	if bool(spec.get("has_spreader", false)):
		spreader = Node3D.new()
		hook_block.add_child(spreader)
		_box(spreader, Vector3(12.2, 0.55, 0.5), Vector3(0.0, -0.3, 0.0), M.CRANE_ORANGE)
		_box(spreader, Vector3(0.6, 0.4, 2.6), Vector3(0.0, -0.3, 0.0), M.CRANE_ORANGE)
		for cx in [-5.9, 5.9]:
			for cz in [-1.15, 1.15]:
				_box(spreader, Vector3(0.35, 0.5, 0.35), Vector3(cx, -0.62, cz), M.STEEL_RAW)
	else:
		_box(hook_block, Vector3(0.42, 0.55, 0.30), Vector3(0.0, -0.28, 0.0), M.STEEL_PAINTED)
		_cyl(hook_block, 0.22, 0.12, Vector3(0.0, -0.10, 0.0), M.STEEL_RAW).rotation.x = PI / 2.0
		var hook := _cyl(hook_block, 0.09, 0.5, Vector3(0.0, -0.75, 0.0), M.STEEL_RAW)
		hook.rotation.z = deg_to_rad(12.0)
		_box(hook_block, Vector3(0.10, 0.24, 0.10), Vector3(0.10, -1.0, 0.0), M.STEEL_RAW)


# --- per-frame sync ------------------------------------------------------------

func sync() -> void:
	if rig == null:
		return
	match String(spec.get("class", MachineCatalog.CLASS_OVERHEAD)):
		MachineCatalog.CLASS_TOWER: _sync_tower()
		MachineCatalog.CLASS_GANTRY, MachineCatalog.CLASS_OVERHEAD: _sync_bridge()
		_: _sync_boom()
	_sync_outriggers()
	_sync_rope()


func _sync_bridge() -> void:
	if bridge != null:
		bridge.position.x = rig.get_axis("travel")
	if trolley != null:
		trolley.position.z = rig.get_axis("trolley")


func _sync_tower() -> void:
	if slew_pivot != null:
		slew_pivot.rotation.y = -rig.get_axis("slew") * PI / 180.0
	if trolley != null:
		trolley.position.x = rig.get_axis("trolley")


func _sync_boom() -> void:
	if slew_pivot != null:
		slew_pivot.rotation.y = -rig.get_axis("slew") * PI / 180.0
	if boom == null:
		return
	boom.rotation.z = rig.get_axis("luff") * PI / 180.0
	if rig.has_axis("travel"):
		position.x = rig.get_axis("travel")

	var g: Dictionary = spec.get("geometry", {})
	var total: float = rig.get_axis("telescope", float(g.get("boom_length", 20.0)))
	for s in boom_sections:
		if s.get("head", false):
			s.node.position = Vector3(total, 0.0, 0.0)
			continue
		if s.get("lattice", false):
			continue
		var count: int = int(s.count)
		var i: int = int(s.index)
		# Section i starts proportionally further out as the boom extends,
		# so the sections visibly slide rather than stretch.
		var extend: float = (total - float(s.min_len)) / float(maxi(1, count - 1))
		s.node.position = Vector3(float(i) * extend, 0.0, 0.0)
		var seg: float = maxf(0.6, total / float(count) * 1.05)
		s.mesh.mesh.size.x = seg
		s.mesh.position.x = seg * 0.5


func _sync_outriggers() -> void:
	if outrigger_beams.is_empty():
		return
	var t: float = rig.outriggers
	for i in outrigger_beams.size():
		var b: Dictionary = outrigger_beams[i]
		var half: Vector2 = b.half
		var reach: float = lerpf(half.x * 0.35, half.x, t)
		b.arm.position.x = b.sx * reach * 0.5
		b.arm.mesh.size.x = reach
		b.leg.position.x = b.sx * reach
		# The pad drops to the ground only once the beam is out — a stowed
		# outrigger with its foot planted would teach the wrong picture.
		b.leg.position.y = lerpf(1.05, 0.45, t)
		b.leg.mesh.size.y = lerpf(0.2, 0.9, t)
		var pad: MeshInstance3D = outrigger_pads[i]
		pad.position.x = b.sx * reach
		pad.position.y = lerpf(0.95, 0.09, t)


func _sync_rope() -> void:
	var head: Vector3 = rig.support_point()
	var hook_len: float = rig.get_axis("hoist")
	var hook_pos := head - Vector3(0.0, hook_len, 0.0)
	hook_block.global_position = hook_pos
	# Hook block hangs plumb even when the machine slews; only the spreader
	# aligns with the boom, which is what a twistlock spreader actually does.
	if spreader != null and rig.has_axis("slew"):
		spreader.rotation.y = -rig.get_axis("slew") * PI / 180.0

	var d := hook_pos - head
	var l := d.length()
	rope.visible = l > 0.05
	if not rope.visible:
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	rope.global_transform = Transform3D(Basis(x, y * l, z), (head + hook_pos) * 0.5)


## World transform of the operator's viewpoint, for the cabin camera.
func operator_eye() -> Transform3D:
	if cabin_anchor != null:
		return cabin_anchor.global_transform
	return Transform3D(Basis(), global_position + Vector3(0.0, 2.0, 0.0))


func has_cabin() -> bool:
	return cabin_anchor != null
