extends Node3D
## CameraDirector — every viewpoint in the simulator on one Camera3D.
##
## HOME is first person from the operator's own eyes: on foot that is the
## walking view, and while operating it is either the same standing view (a
## pendant crane is worked from the floor) or the cab, depending on the
## machine's control kind. Tab cycles the away views; C returns HOME.
##
## The hook and boom-tip cameras are not decoration — a real operator's whole
## problem is that they cannot see the load, and being able to switch to the
## hook view is the simulator's honest substitute for a signaller you cannot
## hear. Assessment mode can restrict them.

enum Mode { HOME, ORBIT, HOOK, TOPDOWN, BOOM }

const CAM_YAW_DEFAULT := 210.0
const CAM_PITCH_DEFAULT := 18.0

## The orbit view has to frame machines from a 9 m workshop crane to a 42 m
## tower crane, so its default distance is derived from the machine rather
## than fixed. A single constant put the camera inside the concrete frame on
## the building site and outside the hall wall indoors.
var orbit_dist_default := 18.0
var orbit_pitch_default := CAM_PITCH_DEFAULT

## World-space limits the orbit camera may not leave. Indoor sites set these to
## the hall's own extents: an unconstrained orbit camera simply flies through
## the cladding and fills the screen with the inside face of a wall, which is
## the single most confusing thing a "look at your crane" view can do.
var bounds_min := Vector3(-1e9, -1e9, -1e9)
var bounds_max := Vector3(1e9, 1e9, 1e9)
var clamp_to_bounds := false

var camera: Camera3D
var mode: int = Mode.HOME

var orbit_yaw := 0.0
var orbit_pitch := 0.0
var orbit_dist := 0.0

var player: Node3D            # PlayerController
var rig: RefCounted           # MachineRig
var visual: Node3D            # MachineVisual
var load_pos := Vector3.ZERO  # current load position, for the hook view
var use_cabin := false        # true while operating a machine that has a cab

var allowed_modes: Array = [Mode.HOME, Mode.ORBIT, Mode.HOOK, Mode.TOPDOWN, Mode.BOOM]

var _shake := 0.0
var _shake_seed := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 900.0
	add_child(camera)
	camera.current = true
	reset_orbit()


func reset_orbit() -> void:
	orbit_yaw = deg_to_rad(CAM_YAW_DEFAULT)
	orbit_pitch = deg_to_rad(orbit_pitch_default)
	orbit_dist = orbit_dist_default


## Called once by the session with the machine's height and the site's ground
## extents, so the orbit view starts framed on the machine and stays indoors
## where indoors is a real constraint.
func configure_framing(machine_height: float, site_min: Vector3, site_max: Vector3,
		indoor: bool) -> void:
	clamp_to_bounds = indoor
	# Margins keep the near plane out of the cladding. The vertical margin is
	# small so the camera can still rise above the crane girder rather than
	# being pinned level with it.
	bounds_min = site_min + Vector3(2.5, 1.2, 2.5)
	bounds_max = site_max - Vector3(2.5, 0.6, 2.5)

	if indoor:
		# Indoors the room, not the machine, sets the distance: a camera pushed
		# out to "machine height x 1.7" simply ends up clamped into a corner,
		# looking along the runway beam. Pull in and look down instead.
		var room: float = minf(site_max.x - site_min.x, site_max.z - site_min.z) * 0.5
		orbit_dist_default = clampf(machine_height * 1.2, 9.0, maxf(9.0, room * 1.25))
		orbit_pitch_default = 32.0
	else:
		orbit_dist_default = clampf(machine_height * 1.7 + 14.0, 16.0, 95.0)
		orbit_pitch_default = CAM_PITCH_DEFAULT
	reset_orbit()


func cycle_mode() -> void:
	if allowed_modes.is_empty():
		return
	var i := allowed_modes.find(mode)
	mode = allowed_modes[(i + 1) % allowed_modes.size()]


func go_home() -> void:
	mode = Mode.HOME
	reset_orbit()


func active_view_name() -> String:
	match mode:
		Mode.ORBIT: return "orbit"
		Mode.HOOK: return "hook"
		Mode.TOPDOWN: return "topdown"
		Mode.BOOM: return "boom"
		_: return "cabin" if use_cabin else "walk"


## Brief camera shake on an impact — the cheapest possible way to make a
## collision *felt* rather than merely counted.
func kick(strength: float = 1.0) -> void:
	_shake = maxf(_shake, clampf(strength, 0.0, 1.5))


func update(delta: float) -> void:
	match mode:
		Mode.ORBIT: _update_orbit(delta)
		Mode.HOOK: _update_hook()
		Mode.TOPDOWN: _update_topdown()
		Mode.BOOM: _update_boom()
		_: _update_home()
	if _shake > 0.001:
		_shake_seed += delta * 47.0
		var amp := _shake * 0.09
		camera.position += Vector3(
			sin(_shake_seed * 1.7) * amp,
			cos(_shake_seed * 2.3) * amp,
			sin(_shake_seed * 3.1) * amp * 0.5)
		_shake = maxf(0.0, _shake - delta * 2.6)


func _update_home() -> void:
	if use_cabin and visual != null and visual.has_method("operator_eye"):
		var t: Transform3D = visual.operator_eye()
		# Look down the boom, with a slight downward tilt — a cab operator
		# spends the whole job looking at the hook, not the horizon.
		camera.global_transform = t.rotated_local(Vector3.RIGHT, deg_to_rad(-14.0))
		return
	if player != null:
		camera.global_transform = player.eye_transform()


func _update_orbit(delta: float) -> void:
	orbit_yaw += Input.get_axis("cam_orbit_right", "cam_orbit_left") * 1.6 * delta
	orbit_pitch = clampf(
		orbit_pitch + Input.get_axis("cam_orbit_down", "cam_orbit_up") * 1.2 * delta,
		deg_to_rad(4.0), deg_to_rad(84.0))
	orbit_dist = clampf(
		orbit_dist + Input.get_axis("cam_zoom_in", "cam_zoom_out") * 14.0 * delta,
		4.0, 160.0)
	var pivot := _machine_pivot()
	var offset := Vector3(
		cos(orbit_yaw) * cos(orbit_pitch),
		sin(orbit_pitch),
		sin(orbit_yaw) * cos(orbit_pitch)) * orbit_dist
	var pos := pivot + offset
	if clamp_to_bounds:
		pos = Vector3(
			clampf(pos.x, bounds_min.x, bounds_max.x),
			clampf(pos.y, bounds_min.y, bounds_max.y),
			clampf(pos.z, bounds_min.z, bounds_max.z))
	camera.global_position = pos
	# A clamped camera can land on the pivot; looking at yourself produces a
	# non-finite basis, so back off along the offset before aiming.
	if pos.distance_to(pivot) < 0.5:
		camera.global_position = pivot + offset.normalized() * 0.5
	camera.look_at(pivot)


## Looking down the rope at the load, from just beside the rope head. This is
## the view that makes a blind set-down possible.
func _update_hook() -> void:
	if rig == null:
		return
	var head: Vector3 = rig.support_point()
	var eye := head + Vector3(1.6, 0.4, 1.6)
	camera.global_position = eye
	var target := load_pos
	if eye.distance_to(target) < 0.2:
		target = eye + Vector3.DOWN
	camera.look_at(target, Vector3.UP)


func _update_topdown() -> void:
	var pivot := _machine_pivot()
	pivot.y = 0.0
	var height := 60.0
	if rig != null and rig.has_axis("trolley"):
		height = maxf(40.0, rig.get_axis("trolley") * 2.2)
	camera.global_position = pivot + Vector3(0.0, height, 0.001)
	camera.look_at(pivot, Vector3.FORWARD)


## Over the boom head, looking along the boom — the view that makes radius
## legible on a slewing machine.
func _update_boom() -> void:
	if rig == null:
		return
	var head: Vector3 = rig.support_point()
	var yaw: float = rig.boom_yaw_rad()
	var back := Vector3(-cos(yaw), 0.0, -sin(yaw)) * 9.0
	camera.global_position = head + back + Vector3(0.0, 4.5, 0.0)
	camera.look_at(head + Vector3(0.0, -3.0, 0.0), Vector3.UP)


## Aim at the middle of the machine's working height rather than at the rope
## head: on a tower crane the head is 42 m up, and pointing there puts the
## whole job off the bottom of the screen.
func _machine_pivot() -> Vector3:
	if rig == null:
		return Vector3.ZERO
	var head: Vector3 = rig.support_point()
	return Vector3(head.x, maxf(2.0, head.y * 0.5), head.z)
