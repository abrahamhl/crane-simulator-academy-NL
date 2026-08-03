extends RefCounted
## Seeded wind model: steady base vector plus Ornstein-Uhlenbeck gusts on the
## horizontal components. Deterministic for a given seed and step sequence.

var base_wind := Vector3.ZERO
var gust_sigma := 2.0            # gust standard deviation, m/s
var gust_tau := 3.0              # gust correlation time, s
var time := 0.0

var _gust := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func setup(seed_value: int, dir_deg: float, speed: float,
		p_sigma: float, p_tau: float) -> void:
	_rng.seed = seed_value
	var rad := deg_to_rad(dir_deg)
	base_wind = Vector3(cos(rad), 0.0, sin(rad)) * speed
	gust_sigma = p_sigma
	gust_tau = maxf(0.1, p_tau)
	_gust = Vector3.ZERO
	time = 0.0


func step(dt: float) -> void:
	var a := exp(-dt / gust_tau)
	var s := gust_sigma * sqrt(1.0 - a * a)
	_gust.x = _gust.x * a + _rng.randfn(0.0, s)
	_gust.z = _gust.z * a + _rng.randfn(0.0, s)
	time += dt


## Ambient wind vector (before any indoor attenuation applied by the caller).
func wind() -> Vector3:
	return base_wind + _gust
