extends Node
## MaterialLibrary — procedural PBR material factory.
##
## Why procedural and not downloaded texture files: the project must stay
## fully offline, license-clean and small in the repository, while still
## looking like a simulator rather than flat-shaded programmer boxes
## (KI-006). Every surface here is built at runtime from FastNoiseLite +
## gradients into real albedo / roughness / normal maps, so we get grain,
## wear, dirt and surface relief without shipping a single binary asset.
##
## Materials are CACHED by id: the hall has ~200 concrete surfaces and they
## must all share one StandardMaterial3D or the renderer builds 200 pipelines.
## Call `get_mat(MaterialLibrary.CONCRETE)` — never construct inline.
##
## Determinism: every noise generator is explicitly seeded from the material
## id, so two runs produce byte-identical textures. Nothing here reads the
## global RNG.

const CONCRETE := "concrete"
const CONCRETE_DIRTY := "concrete_dirty"
const ASPHALT := "asphalt"
const TARMAC := "tarmac"
const GRAVEL := "gravel"
const SOIL := "soil"
const GRASS := "grass"
const SAND := "sand"
const STEEL_PAINTED := "steel_painted"
const STEEL_RAW := "steel_raw"
const STEEL_RUSTY := "steel_rusty"
const STEEL_GALV := "steel_galv"
const CRANE_YELLOW := "crane_yellow"
const CRANE_ORANGE := "crane_orange"
const CRANE_RED := "crane_red"
const HAZARD_STRIPE := "hazard_stripe"
const CORRUGATED := "corrugated"
const BRICK := "brick"
const WOOD := "wood"
const WOOD_PALLET := "wood_pallet"
const RUBBER := "rubber"
const GLASS := "glass"
const WATER := "water"
const CONTAINER_BLUE := "container_blue"
const CONTAINER_RED := "container_red"
const CONTAINER_GREEN := "container_green"
const CONTAINER_GREY := "container_grey"
const RAIL_STEEL := "rail_steel"
const BALLAST := "ballast"
const HIVIS := "hivis"
const CABLE := "cable"
const SNOW := "snow"

## Texture resolution. 256 px reads well on desktop; the web build halves it
## because generating 30 materials' worth of noise fields in WASM at 256² adds
## seconds to the first scene load, and at browser viewport sizes the
## difference is invisible. A var (not const) so the web branch can lower it
## before the first material is built.
var TEX_SIZE := 256

## Tuning table: id -> {base, alt, rough, metal, noise, freq, bump, uv}
## base/alt   : the two ends of the albedo gradient the noise interpolates
## rough      : base roughness (noise perturbs it +-0.15)
## metal      : metallic value
## noise      : "simplex" | "cellular" | "value" | "perlin"
## freq       : noise frequency (higher = finer grain)
## bump       : normal-map strength, 0 disables the normal map
## uv         : world-space UV scale (triplanar), metres per texture tile
const SPEC := {
	CONCRETE:        {base = Color(0.52, 0.52, 0.54), alt = Color(0.38, 0.38, 0.40), rough = 0.88, metal = 0.0, noise = "simplex",  freq = 0.045, bump = 0.35, uv = 2.5},
	CONCRETE_DIRTY:  {base = Color(0.40, 0.39, 0.37), alt = Color(0.24, 0.23, 0.22), rough = 0.93, metal = 0.0, noise = "simplex",  freq = 0.030, bump = 0.45, uv = 3.0},
	ASPHALT:         {base = Color(0.19, 0.19, 0.20), alt = Color(0.10, 0.10, 0.11), rough = 0.95, metal = 0.0, noise = "cellular", freq = 0.120, bump = 0.60, uv = 2.0},
	TARMAC:          {base = Color(0.26, 0.26, 0.27), alt = Color(0.15, 0.15, 0.16), rough = 0.92, metal = 0.0, noise = "cellular", freq = 0.090, bump = 0.50, uv = 2.5},
	GRAVEL:          {base = Color(0.50, 0.47, 0.43), alt = Color(0.27, 0.25, 0.23), rough = 0.97, metal = 0.0, noise = "cellular", freq = 0.220, bump = 1.00, uv = 1.2},
	SOIL:            {base = Color(0.34, 0.26, 0.18), alt = Color(0.19, 0.14, 0.09), rough = 0.98, metal = 0.0, noise = "simplex",  freq = 0.070, bump = 0.70, uv = 2.0},
	GRASS:           {base = Color(0.28, 0.42, 0.19), alt = Color(0.16, 0.27, 0.11), rough = 0.95, metal = 0.0, noise = "simplex",  freq = 0.180, bump = 0.40, uv = 1.5},
	SAND:            {base = Color(0.72, 0.64, 0.48), alt = Color(0.55, 0.48, 0.35), rough = 0.94, metal = 0.0, noise = "simplex",  freq = 0.150, bump = 0.35, uv = 1.5},
	STEEL_PAINTED:   {base = Color(0.42, 0.46, 0.52), alt = Color(0.32, 0.35, 0.40), rough = 0.45, metal = 0.55, noise = "simplex", freq = 0.060, bump = 0.15, uv = 2.0},
	STEEL_RAW:       {base = Color(0.55, 0.57, 0.60), alt = Color(0.40, 0.42, 0.45), rough = 0.38, metal = 0.85, noise = "simplex", freq = 0.080, bump = 0.20, uv = 2.0},
	STEEL_RUSTY:     {base = Color(0.48, 0.28, 0.15), alt = Color(0.28, 0.26, 0.25), rough = 0.80, metal = 0.35, noise = "simplex", freq = 0.055, bump = 0.55, uv = 1.8},
	STEEL_GALV:      {base = Color(0.62, 0.64, 0.66), alt = Color(0.48, 0.50, 0.53), rough = 0.30, metal = 0.80, noise = "cellular", freq = 0.070, bump = 0.20, uv = 2.0},
	CRANE_YELLOW:    {base = Color(0.92, 0.72, 0.08), alt = Color(0.72, 0.54, 0.05), rough = 0.42, metal = 0.30, noise = "simplex",  freq = 0.050, bump = 0.18, uv = 2.0},
	CRANE_ORANGE:    {base = Color(0.88, 0.42, 0.06), alt = Color(0.66, 0.30, 0.04), rough = 0.44, metal = 0.30, noise = "simplex",  freq = 0.050, bump = 0.18, uv = 2.0},
	CRANE_RED:       {base = Color(0.72, 0.14, 0.11), alt = Color(0.50, 0.09, 0.07), rough = 0.46, metal = 0.28, noise = "simplex",  freq = 0.050, bump = 0.18, uv = 2.0},
	HAZARD_STRIPE:   {base = Color(0.95, 0.80, 0.05), alt = Color(0.08, 0.08, 0.08), rough = 0.55, metal = 0.10, noise = "stripe",   freq = 0.500, bump = 0.10, uv = 1.0},
	CORRUGATED:      {base = Color(0.58, 0.60, 0.63), alt = Color(0.40, 0.42, 0.45), rough = 0.48, metal = 0.60, noise = "ridge",    freq = 0.400, bump = 0.90, uv = 3.0},
	BRICK:           {base = Color(0.52, 0.28, 0.21), alt = Color(0.36, 0.19, 0.14), rough = 0.90, metal = 0.0, noise = "brick",     freq = 0.250, bump = 0.80, uv = 2.0},
	WOOD:            {base = Color(0.55, 0.40, 0.24), alt = Color(0.38, 0.26, 0.14), rough = 0.75, metal = 0.0, noise = "grain",     freq = 0.150, bump = 0.35, uv = 1.5},
	WOOD_PALLET:     {base = Color(0.66, 0.52, 0.34), alt = Color(0.45, 0.34, 0.20), rough = 0.82, metal = 0.0, noise = "grain",     freq = 0.220, bump = 0.45, uv = 0.8},
	RUBBER:          {base = Color(0.12, 0.12, 0.13), alt = Color(0.06, 0.06, 0.07), rough = 0.92, metal = 0.0, noise = "cellular",  freq = 0.180, bump = 0.35, uv = 1.0},
	GLASS:           {base = Color(0.55, 0.68, 0.75), alt = Color(0.45, 0.58, 0.68), rough = 0.06, metal = 0.10, noise = "simplex",  freq = 0.020, bump = 0.0,  uv = 2.0},
	WATER:           {base = Color(0.10, 0.22, 0.30), alt = Color(0.06, 0.15, 0.24), rough = 0.10, metal = 0.20, noise = "simplex",  freq = 0.035, bump = 0.30, uv = 6.0},
	CONTAINER_BLUE:  {base = Color(0.10, 0.29, 0.52), alt = Color(0.06, 0.20, 0.38), rough = 0.55, metal = 0.35, noise = "ridge",    freq = 0.350, bump = 0.70, uv = 2.5},
	CONTAINER_RED:   {base = Color(0.56, 0.14, 0.12), alt = Color(0.38, 0.09, 0.08), rough = 0.58, metal = 0.35, noise = "ridge",    freq = 0.350, bump = 0.70, uv = 2.5},
	CONTAINER_GREEN: {base = Color(0.13, 0.36, 0.22), alt = Color(0.08, 0.24, 0.15), rough = 0.58, metal = 0.35, noise = "ridge",    freq = 0.350, bump = 0.70, uv = 2.5},
	CONTAINER_GREY:  {base = Color(0.44, 0.45, 0.46), alt = Color(0.30, 0.31, 0.32), rough = 0.60, metal = 0.35, noise = "ridge",    freq = 0.350, bump = 0.70, uv = 2.5},
	RAIL_STEEL:      {base = Color(0.42, 0.40, 0.38), alt = Color(0.26, 0.24, 0.22), rough = 0.35, metal = 0.90, noise = "simplex",  freq = 0.090, bump = 0.25, uv = 1.5},
	BALLAST:         {base = Color(0.44, 0.42, 0.40), alt = Color(0.22, 0.21, 0.20), rough = 0.98, metal = 0.0,  noise = "cellular", freq = 0.300, bump = 1.00, uv = 1.0},
	HIVIS:           {base = Color(0.95, 0.85, 0.05), alt = Color(0.80, 0.55, 0.03), rough = 0.70, metal = 0.0,  noise = "simplex",  freq = 0.100, bump = 0.10, uv = 1.0},
	CABLE:           {base = Color(0.20, 0.20, 0.22), alt = Color(0.10, 0.10, 0.11), rough = 0.55, metal = 0.70, noise = "grain",    freq = 0.600, bump = 0.50, uv = 0.4},
	SNOW:            {base = Color(0.92, 0.94, 0.97), alt = Color(0.78, 0.82, 0.88), rough = 0.75, metal = 0.0,  noise = "simplex",  freq = 0.060, bump = 0.30, uv = 3.0},
}

var _cache: Dictionary = {}
var _tex_cache: Dictionary = {}
var _enabled := true


func _ready() -> void:
	if OS.has_feature("web"):
		TEX_SIZE = 128


## Headless test runs skip texture generation entirely — 30 noise textures at
## 256x256 is wasted work when nothing is rasterised, and it keeps the
## selftest fast. Materials still come back valid, just flat-coloured.
func set_texture_generation(enabled: bool) -> void:
	if enabled != _enabled:
		_enabled = enabled
		_cache.clear()
		_tex_cache.clear()


func has(id: String) -> bool:
	return SPEC.has(id)


## The one entry point. Returns a shared, cached StandardMaterial3D.
func get_mat(id: String) -> StandardMaterial3D:
	if _cache.has(id):
		return _cache[id]
	var mat := _build(id)
	_cache[id] = mat
	return mat


## A per-call COPY of a library material, for the few cases that need a unique
## tweak (a tinted container, a flashing lamp). Costs a material slot — use
## get_mat() everywhere else.
func variant(id: String, albedo_tint: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = get_mat(id).duplicate()
	mat.albedo_color = albedo_tint
	return mat


## Flat unshaded material for HUD-in-world markers (zone discs, beams, decals).
## These must NOT react to weather lighting — a drop-off zone has to stay
## readable at night and in fog, which is the whole point of marking it.
func unshaded(color: Color) -> StandardMaterial3D:
	var key := "unshaded_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = mat
	return mat


# --- construction ------------------------------------------------------------

func _build(id: String) -> StandardMaterial3D:
	var s: Dictionary = SPEC.get(id, SPEC[CONCRETE])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.roughness = s.rough
	mat.metallic = s.metal

	if not _enabled:
		mat.albedo_color = s.base
		return mat

	mat.albedo_texture = _albedo_tex(id, s)
	mat.roughness_texture = _rough_tex(id, s)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if s.bump > 0.0:
		mat.normal_enabled = true
		mat.normal_texture = _normal_tex(id, s)
		mat.normal_scale = s.bump

	# Triplanar in WORLD space: every surface in the level then shares one
	# material and one UV convention regardless of how the box was scaled.
	# Without this, a 64x22 m floor box stretches its texture to mush.
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / maxf(0.01, s.uv)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	if id == GLASS or id == WATER:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.55 if id == GLASS else 0.85)
	return mat


func _albedo_tex(id: String, s: Dictionary) -> ImageTexture:
	var key := "a_" + id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(TEX_SIZE, TEX_SIZE, true, Image.FORMAT_RGB8)
	var f := _field(id, s)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			img.set_pixel(x, y, s.base.lerp(s.alt, f[y * TEX_SIZE + x]))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


func _rough_tex(id: String, s: Dictionary) -> ImageTexture:
	var key := "r_" + id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(TEX_SIZE, TEX_SIZE, true, Image.FORMAT_RGB8)
	var f := _field(id, s)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			# Darker/worn patches read as rougher: correlate roughness with the
			# same field that drives albedo, which is what real wear looks like.
			var r := clampf(s.rough + (f[y * TEX_SIZE + x] - 0.5) * 0.30, 0.02, 1.0)
			img.set_pixel(x, y, Color(r, r, r))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


## Normal map derived from the height field by central differences. Godot's
## normal-map convention is tangent space with +Y up, packed into RG.
func _normal_tex(id: String, s: Dictionary) -> ImageTexture:
	var key := "n_" + id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var f := _field(id, s)
	var img := Image.create(TEX_SIZE, TEX_SIZE, true, Image.FORMAT_RGB8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var xl := f[y * TEX_SIZE + (x - 1 + TEX_SIZE) % TEX_SIZE]
			var xr := f[y * TEX_SIZE + (x + 1) % TEX_SIZE]
			var yu := f[((y - 1 + TEX_SIZE) % TEX_SIZE) * TEX_SIZE + x]
			var yd := f[((y + 1) % TEX_SIZE) * TEX_SIZE + x]
			var n := Vector3((xl - xr) * 2.0, (yu - yd) * 2.0, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


## The shared scalar height/wear field in [0,1] every map is derived from, so
## albedo, roughness and relief all agree about where the dents and dirt are.
## Cached per material id: it is generated once and read three times.
func _field(id: String, s: Dictionary) -> PackedFloat32Array:
	var key := "f_" + id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var out := PackedFloat32Array()
	out.resize(TEX_SIZE * TEX_SIZE)
	var seed_value := hash(id) & 0x7fffffff
	match String(s.noise):
		"stripe":
			_fill_stripes(out)
		"ridge":
			_fill_ridges(out, s.freq)
		"brick":
			_fill_bricks(out, seed_value)
		"grain":
			_fill_grain(out, s.freq, seed_value)
		_:
			_fill_noise(out, String(s.noise), s.freq, seed_value)
	_tex_cache[key] = out
	return out


func _fill_noise(out: PackedFloat32Array, kind: String, freq: float, seed_value: int) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	match kind:
		"cellular":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
		"value":
			n.noise_type = FastNoiseLite.TYPE_VALUE
		"perlin":
			n.noise_type = FastNoiseLite.TYPE_PERLIN
		_:
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_octaves = 4
	n.fractal_lacunarity = 2.1
	n.fractal_gain = 0.5
	# A second, much finer layer adds the pitting/speckle that sells the
	# material up close; the base octaves alone look like smooth marble.
	var fine := FastNoiseLite.new()
	fine.seed = seed_value ^ 0x5bf03635
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fine.frequency = freq * 6.0
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var v := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			v = clampf(v * 0.82 + (fine.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) * 0.18, 0.0, 1.0)
			out[y * TEX_SIZE + x] = v


## Diagonal black/yellow hazard bars — the universal "keep clear" marking.
func _fill_stripes(out: PackedFloat32Array) -> void:
	var period := 48.0
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var t: float = fmod(float(x + y), period) / period
			out[y * TEX_SIZE + x] = 0.0 if t < 0.5 else 1.0


## Vertical corrugation — shipping-container / cladding profile.
func _fill_ridges(out: PackedFloat32Array, freq: float) -> void:
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			out[y * TEX_SIZE + x] = sin(float(x) * freq) * 0.5 + 0.5


func _fill_bricks(out: PackedFloat32Array, seed_value: int) -> void:
	var bw := 64
	var bh := 24
	var mortar := 3
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in TEX_SIZE:
		var row := int(y / bh)
		var offset := (row % 2) * int(bw / 2)
		var shade := 0.35 + rng.randf_range(-0.12, 0.12)
		for x in TEX_SIZE:
			var lx := (x + offset) % bw
			var ly := y % bh
			var is_mortar := lx < mortar or ly < mortar
			out[y * TEX_SIZE + x] = 1.0 if is_mortar else clampf(shade, 0.0, 1.0)


## Directional wood grain: stretched noise along one axis plus growth rings.
func _fill_grain(out: PackedFloat32Array, freq: float, seed_value: int) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = freq
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var warp := n.get_noise_2d(float(x) * 0.4, float(y) * 4.0) * 12.0
			var rings: float = sin((float(y) + warp) * 0.55) * 0.5 + 0.5
			out[y * TEX_SIZE + x] = clampf(rings * 0.75 + (n.get_noise_2d(float(x), float(y) * 8.0) * 0.5 + 0.5) * 0.25, 0.0, 1.0)
