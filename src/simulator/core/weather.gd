extends Node
## Weather — named condition presets that drive lighting, sky, fog, wind and
## visibility together, so "rain at dusk" is one selection rather than six
## sliders the learner has to guess at.
##
## Weather is not decoration here. Three things it changes are examinable:
##   * wind      — the multiplier on the scenario's base wind, and the gusting.
##                 Lifting work has real wind limits; above them you stop.
##   * visibility— fog and darkness force reliance on the signaller and on
##                 planning the path before moving, not on eyeballing it.
##   * ground    — rain and snow reduce the ground bearing quality used by the
##                 outrigger check, and make a poorly-planned set-up fail.
##
## WIND LIMIT NOTE: the `wind_limit_ms` on each preset is a TRAINING default,
## not a legal or manufacturer limit. Real limits come from the machine's own
## documentation and the lift plan, and are usually stricter for large-surface
## loads. The UI states this. Never present it as a regulatory threshold.

const LocText := preload("res://core/loc.gd")

const CLEAR := "clear"
const OVERCAST := "overcast"
const RAIN := "rain"
const FOG := "fog"
const DUSK := "dusk"
const NIGHT := "night"
const STORM := "storm"
const SNOW := "snow"

const ORDER := [CLEAR, OVERCAST, RAIN, FOG, DUSK, NIGHT, SNOW, STORM]

## wind_mul        multiplier on the scenario's base wind speed
## gust_mul        multiplier on gust sigma (turbulence, not mean speed)
## wind_limit_ms   training stop-work threshold shown on the HUD
## sun_energy      directional light strength
## sun_angle       (pitch, yaw) degrees for the sun/moon
## sun_color       light tint
## sky_top/horizon procedural sky colours
## ambient         ambient light energy
## fog_density     0 disables fog
## fog_color       fog tint
## ground_grip     0..1 multiplier on outrigger ground bearing quality
## precip          "none" | "rain" | "snow" — particle layer
## visibility_m    advisory sight distance shown in the briefing
const PRESETS := {
	CLEAR: {
		"name": {"en": "Clear", "es": "Despejado", "nl": "Helder"},
		"wind_mul": 0.6, "gust_mul": 0.5, "wind_limit_ms": 14.0,
		"sun_energy": 1.35, "sun_angle": Vector2(-52.0, -38.0), "sun_color": Color(1.0, 0.96, 0.88),
		"sky_top": Color(0.28, 0.48, 0.82), "sky_horizon": Color(0.72, 0.82, 0.92),
		"ambient": 0.55, "fog_density": 0.0006, "fog_color": Color(0.72, 0.80, 0.90),
		"ground_grip": 1.0, "precip": "none", "visibility_m": 2000.0, "tier": 1,
	},
	OVERCAST: {
		"name": {"en": "Overcast", "es": "Nublado", "nl": "Bewolkt"},
		"wind_mul": 1.0, "gust_mul": 1.0, "wind_limit_ms": 12.0,
		"sun_energy": 0.75, "sun_angle": Vector2(-46.0, -25.0), "sun_color": Color(0.90, 0.92, 0.96),
		"sky_top": Color(0.42, 0.46, 0.52), "sky_horizon": Color(0.62, 0.65, 0.70),
		"ambient": 0.70, "fog_density": 0.0022, "fog_color": Color(0.62, 0.65, 0.70),
		"ground_grip": 0.95, "precip": "none", "visibility_m": 900.0, "tier": 1,
	},
	RAIN: {
		"name": {"en": "Rain", "es": "Lluvia", "nl": "Regen"},
		"wind_mul": 1.35, "gust_mul": 1.4, "wind_limit_ms": 11.0,
		"sun_energy": 0.45, "sun_angle": Vector2(-40.0, -18.0), "sun_color": Color(0.80, 0.84, 0.90),
		"sky_top": Color(0.28, 0.31, 0.36), "sky_horizon": Color(0.46, 0.49, 0.54),
		"ambient": 0.55, "fog_density": 0.0075, "fog_color": Color(0.50, 0.54, 0.60),
		"ground_grip": 0.72, "precip": "rain", "visibility_m": 350.0, "tier": 2,
	},
	FOG: {
		"name": {"en": "Fog", "es": "Niebla", "nl": "Mist"},
		"wind_mul": 0.25, "gust_mul": 0.3, "wind_limit_ms": 12.0,
		"sun_energy": 0.35, "sun_angle": Vector2(-58.0, -30.0), "sun_color": Color(0.86, 0.88, 0.92),
		"sky_top": Color(0.60, 0.62, 0.65), "sky_horizon": Color(0.70, 0.72, 0.74),
		"ambient": 0.85, "fog_density": 0.0380, "fog_color": Color(0.70, 0.72, 0.75),
		"ground_grip": 0.88, "precip": "none", "visibility_m": 45.0, "tier": 3,
	},
	DUSK: {
		"name": {"en": "Dusk", "es": "Atardecer", "nl": "Schemering"},
		"wind_mul": 0.8, "gust_mul": 0.8, "wind_limit_ms": 13.0,
		"sun_energy": 0.60, "sun_angle": Vector2(-8.0, -72.0), "sun_color": Color(1.0, 0.66, 0.42),
		"sky_top": Color(0.16, 0.20, 0.38), "sky_horizon": Color(0.86, 0.48, 0.26),
		"ambient": 0.38, "fog_density": 0.0055, "fog_color": Color(0.42, 0.34, 0.36),
		"ground_grip": 0.95, "precip": "none", "visibility_m": 600.0, "tier": 2,
	},
	NIGHT: {
		"name": {"en": "Night", "es": "Noche", "nl": "Nacht"},
		"wind_mul": 0.7, "gust_mul": 0.7, "wind_limit_ms": 12.0,
		"sun_energy": 0.10, "sun_angle": Vector2(-62.0, 40.0), "sun_color": Color(0.55, 0.62, 0.85),
		"sky_top": Color(0.03, 0.04, 0.09), "sky_horizon": Color(0.09, 0.11, 0.18),
		"ambient": 0.16, "fog_density": 0.0090, "fog_color": Color(0.07, 0.08, 0.13),
		"ground_grip": 0.92, "precip": "none", "visibility_m": 120.0, "tier": 3,
		"needs_worklights": true,
	},
	SNOW: {
		"name": {"en": "Snow", "es": "Nieve", "nl": "Sneeuw"},
		"wind_mul": 1.1, "gust_mul": 1.2, "wind_limit_ms": 11.0,
		"sun_energy": 0.55, "sun_angle": Vector2(-38.0, -20.0), "sun_color": Color(0.92, 0.94, 1.0),
		"sky_top": Color(0.55, 0.58, 0.64), "sky_horizon": Color(0.76, 0.78, 0.82),
		"ambient": 0.80, "fog_density": 0.0140, "fog_color": Color(0.78, 0.80, 0.84),
		"ground_grip": 0.55, "precip": "snow", "visibility_m": 180.0, "tier": 3,
		"snow_cover": true,
	},
	STORM: {
		"name": {"en": "Storm", "es": "Tormenta", "nl": "Storm"},
		"wind_mul": 2.1, "gust_mul": 2.4, "wind_limit_ms": 9.0,
		"sun_energy": 0.30, "sun_angle": Vector2(-34.0, -12.0), "sun_color": Color(0.72, 0.76, 0.86),
		"sky_top": Color(0.14, 0.15, 0.19), "sky_horizon": Color(0.30, 0.31, 0.35),
		"ambient": 0.42, "fog_density": 0.0130, "fog_color": Color(0.34, 0.36, 0.42),
		"ground_grip": 0.60, "precip": "rain", "visibility_m": 160.0, "tier": 3,
		# Storm is a teaching case as much as a challenge: the correct answer
		# is very often "do not lift". Scenarios can require the operator to
		# recognise that and stop, which scores as a pass, not a failure.
		"stop_work_expected": true,
	},
}


func get_preset(id: String) -> Dictionary:
	return PRESETS.get(id, PRESETS[CLEAR])


func has_weather(id: String) -> bool:
	return PRESETS.has(id)


func display_name(id: String) -> String:
	return LocText.pick(get_preset(id).get("name", {}))


## Wind speed actually applied, given a scenario's base wind and the weather.
func effective_wind_ms(id: String, base_ms: float) -> float:
	return base_ms * float(get_preset(id).get("wind_mul", 1.0))


func effective_gust_sigma(id: String, base_sigma: float) -> float:
	return base_sigma * float(get_preset(id).get("gust_mul", 1.0))


## True when the applied wind is over this preset's training stop-work
## threshold. Scenarios use it to expect an operator to halt.
func over_wind_limit(id: String, applied_ms: float) -> bool:
	return applied_ms > float(get_preset(id).get("wind_limit_ms", 99.0))


## Builds the WorldEnvironment + sun for a preset. `indoor` suppresses the sky
## and precipitation: a factory hall has a roof, and rain inside it would be a
## bug, not weather. Indoor scenes still get the ambient/colour shift so a
## night shift inside the hall still looks and plays like a night shift.
func apply(root: Node3D, id: String, indoor: bool) -> Dictionary:
	var p := get_preset(id)

	var env := Environment.new()
	if indoor:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(p.sky_top).darkened(0.45)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(p.fog_color).lightened(0.15)
		env.ambient_light_energy = maxf(0.35, float(p.ambient) * 0.9)
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = p.sky_top
		sky_mat.sky_horizon_color = p.sky_horizon
		sky_mat.ground_bottom_color = Color(p.sky_horizon).darkened(0.55)
		sky_mat.ground_horizon_color = Color(p.sky_horizon).darkened(0.30)
		sky_mat.sun_angle_max = 12.0
		sky_mat.energy_multiplier = clampf(float(p.ambient) * 1.2, 0.15, 1.6)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = float(p.ambient)
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	var density := float(p.fog_density)
	if indoor:
		density = minf(density, 0.004)   # a roof keeps most of the weather out
	env.fog_enabled = density > 0.0
	env.fog_light_color = p.fog_color
	env.fog_density = density
	env.fog_sky_affect = 0.0 if indoor else 1.0

	# Tone mapping + SSAO + glow: the cheap trio that moves the picture from
	# "flat viewport" to "simulator". Filmic keeps highlights from blowing out
	# at midday and keeps the night preset from crushing to pure black.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	# The web demo runs on the Compatibility renderer (WebGL2), which has no
	# SSAO and pays real frame time for glow on weak laptops. Ambient light is
	# raised slightly instead so interiors do not read darker than desktop.
	if OS.has_feature("web"):
		env.ssao_enabled = false
		env.glow_enabled = false
		env.ambient_light_energy *= 1.15
	else:
		env.ssao_enabled = true
		env.ssao_radius = 1.4
		env.ssao_intensity = 1.8
		env.glow_enabled = true
		env.glow_intensity = 0.35 if float(p.ambient) > 0.4 else 0.75
		env.glow_bloom = 0.10
	env.ssil_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.04

	var we := WorldEnvironment.new()
	we.name = "WeatherEnvironment"
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var ang: Vector2 = p.sun_angle
	sun.rotation_degrees = Vector3(ang.x, ang.y, 0.0)
	sun.light_energy = p.sun_energy
	sun.light_color = p.sun_color
	if indoor:
		# A hall has a roof, and a shadow-casting directional light behind that
		# roof puts the entire floor in darkness — which is what happened, and
		# it made the workshop crane almost unreadable. Indoors the sun stands
		# in for diffuse daylight through the roof panels: no shadow, reduced
		# energy, and the interior lamps below do the modelling.
		sun.shadow_enabled = false
		sun.light_energy = maxf(0.25, float(p.sun_energy) * 0.55)
	else:
		sun.shadow_enabled = true
		if OS.has_feature("web"):
			# WebGL2 pays dearly for 4-split PSSM; 2 splits at a shorter range
			# keeps shadows present without halving the frame rate.
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 120.0
		else:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 180.0
		sun.shadow_bias = 0.04
	root.add_child(sun)

	return {"environment": env, "sun": sun, "preset": p}


## Rain/snow as a GPU particle volume that follows the camera. Cheap, offline,
## and the single biggest "this is a real simulator" visual cue after fog.
func build_precipitation(id: String) -> GPUParticles3D:
	var p := get_preset(id)
	var kind := String(p.get("precip", "none"))
	if kind == "none":
		return null

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(26.0, 1.0, 26.0)
	mat.direction = Vector3(0.15, -1.0, 0.05)
	mat.spread = 4.0 if kind == "rain" else 22.0
	mat.gravity = Vector3(0.0, -14.0 if kind == "rain" else -1.6, 0.0)
	mat.initial_velocity_min = 12.0 if kind == "rain" else 1.0
	mat.initial_velocity_max = 17.0 if kind == "rain" else 2.2
	mat.scale_min = 0.6
	mat.scale_max = 1.0

	var mesh: Mesh
	var vis := StandardMaterial3D.new()
	vis.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vis.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vis.vertex_color_use_as_albedo = false
	vis.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if kind == "rain":
		var q := QuadMesh.new()
		q.size = Vector2(0.02, 0.62)
		mesh = q
		vis.albedo_color = Color(0.72, 0.80, 0.92, 0.42)
		vis.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	else:
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.05, 0.05)
		mesh = q2
		vis.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	mesh.surface_set_material(0, vis)

	var particles := GPUParticles3D.new()
	particles.name = "Precipitation"
	particles.amount = 5000 if kind == "rain" else 3000
	if OS.has_feature("web"):
		particles.amount = particles.amount / 3
	particles.lifetime = 2.2 if kind == "rain" else 8.0
	particles.preprocess = 2.0
	particles.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	particles.process_material = mat
	particles.draw_pass_1 = mesh
	particles.local_coords = false
	return particles
