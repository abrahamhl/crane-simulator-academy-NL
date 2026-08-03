extends RefCounted
## Deterministic fixed-step suspended-load model.
## Point-mass load on an elastic, tension-only cable below a kinematic support
## point, with quadratic aerodynamic drag. Pure math — safe to run headless.
##
## Validation reference (small angle, ideal): T = 2*PI*sqrt(L/g).
## Real deviations modelled: cable elasticity, slack/shock loading, drag,
## support acceleration coupling, wind.

const G := 9.80665
const RHO_AIR := 1.225

var dt := 1.0 / 120.0
var mass := 500.0
var drag_cd := 1.2
var drag_area := 2.0            # projected area facing airflow, m^2
var static_stretch_ratio := 0.002  # cable stretch under static load (0.2%)
var axial_zeta := 0.15          # axial (along-cable) damping ratio

var cable_length := 10.0:
	set(value):
		cable_length = maxf(0.5, value)
		_update_cable_constants()

var support_pos := Vector3.ZERO
var load_pos := Vector3.ZERO
var load_vel := Vector3.ZERO
var tension := 0.0
var time := 0.0

var _k := 0.0
var _c := 0.0


func setup(p_support: Vector3, p_length: float, p_mass: float, p_area: float,
		p_cd: float, p_dt: float = 1.0 / 120.0) -> void:
	dt = p_dt
	mass = p_mass
	drag_area = p_area
	drag_cd = p_cd
	support_pos = p_support
	cable_length = p_length  # setter derives spring constants from mass
	load_pos = p_support + Vector3(0.0, -cable_length, 0.0)
	load_vel = Vector3.ZERO
	tension = 0.0
	time = 0.0


func _update_cable_constants() -> void:
	_k = mass * G / (static_stretch_ratio * cable_length)
	_c = 2.0 * axial_zeta * sqrt(_k * mass)


## Place the load at a swing angle (radians) from vertical, at rest.
func displace_angle(angle_rad: float, azimuth_rad: float = 0.0) -> void:
	var horiz := sin(angle_rad) * cable_length
	load_pos = support_pos + Vector3(
		cos(azimuth_rad) * horiz,
		-cos(angle_rad) * cable_length,
		sin(azimuth_rad) * horiz)
	load_vel = Vector3.ZERO


## Advance one fixed step. Support point is driven kinematically by the crane.
func step(new_support: Vector3, wind_vel: Vector3) -> void:
	var support_vel := (new_support - support_pos) / dt
	support_pos = new_support

	var delta := load_pos - support_pos
	var dist := delta.length()
	var force := Vector3(0.0, -mass * G, 0.0)

	tension = 0.0
	if dist > cable_length and dist > 0.0001:
		var dir := delta / dist
		var stretch := dist - cable_length
		var stretch_rate := (load_vel - support_vel).dot(dir)
		tension = maxf(0.0, _k * stretch + _c * stretch_rate)
		force += -tension * dir

	var v_rel := load_vel - wind_vel
	var v_rel_len := v_rel.length()
	if v_rel_len > 0.0001 and drag_area > 0.0:
		force += -0.5 * RHO_AIR * drag_cd * drag_area * v_rel_len * v_rel

	# Semi-implicit (symplectic) Euler: bounded energy drift, deterministic.
	load_vel += (force / mass) * dt
	load_pos += load_vel * dt
	time += dt

	if not (load_pos.is_finite() and load_vel.is_finite()):
		# Rule: fail visibly on NaN/Infinity, never continue corrupted state.
		push_error("CableLoadSim: non-finite state at t=%f" % time)
		@warning_ignore("assert_always_false")
		assert(false, "CableLoadSim produced non-finite state")


func swing_angle_rad() -> float:
	var delta := load_pos - support_pos
	if delta.length() < 0.0001:
		return 0.0
	return Vector3.DOWN.angle_to(delta.normalized())


func kinetic_energy() -> float:
	return 0.5 * mass * load_vel.length_squared()


func potential_energy() -> float:
	return mass * G * load_pos.y


func spring_energy() -> float:
	var stretch := maxf(0.0, (load_pos - support_pos).length() - cable_length)
	return 0.5 * _k * stretch * stretch


func total_energy() -> float:
	return kinetic_energy() + potential_energy() + spring_energy()
