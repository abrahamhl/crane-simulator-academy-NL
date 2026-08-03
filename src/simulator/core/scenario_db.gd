extends Node
## ScenarioDB — loads, validates and indexes every scenario JSON.
##
## Scenarios are data, not code: adding a job means adding one file under
## `res://scenarios/`. This autoload reads them all at start-up, rejects
## malformed ones LOUDLY (a silently-skipped scenario is how a training
## programme quietly develops a hole), and exposes them ordered for the
## training programme and grouped for the free-choice scenario browser.
##
## Every id is stable and referenced by the learner's saved progress, so an id
## must never be reused for a different job.

const LocText := preload("res://core/loc.gd")

const DIR := "res://scenarios/"

## Catalogues are reached through preloaded SCRIPTS rather than their autoload
## globals so this module compiles and validates standalone — the same reason
## Guidance carries no Loc dependency. Progress lookups, which genuinely need
## live state, live in the menu instead of here.
const Catalog := preload("res://core/machine_catalog.gd")
const EnvCatalog := preload("res://core/environment_catalog.gd")
const WeatherScript := preload("res://core/weather.gd")

## Ordered curriculum tracks. A learner working through "Training programme"
## walks these in order; the scenario browser ignores them.
const PROGRAMMES := {
	"basic_indoor": {
		"order": 1,
		"name": {"en": "1 · Indoor lifting basics", "es": "1 · Fundamentos de elevación en interior", "nl": "1 · Basis binnenhijsen"},
		"desc": {"en": "Pendant-operated bridge crane. Hoisting, travelling, controlling swing, setting down accurately.",
			"es": "Puente grúa con mando colgante. Izar, trasladar, controlar el balanceo y depositar con precisión.",
			"nl": "Bovenloopkraan met hangbediening. Hijsen, rijden, slingering beheersen, nauwkeurig neerzetten."},
	},
	"street_loader": {
		"order": 2,
		"name": {"en": "2 · Lorry loader in the street", "es": "2 · Grúa autocargante en calle", "nl": "2 · Autolaadkraan op straat"},
		"desc": {"en": "Set-up, outriggers, working next to the public, reading a load chart for the first time.",
			"es": "Estacionamiento, estabilizadores, trabajar junto al público y leer por primera vez una tabla de cargas.",
			"nl": "Opstellen, stempelen, werken naast publiek, laadtabel lezen."},
	},
	"tower_site": {
		"order": 3,
		"name": {"en": "3 · Tower crane on a building site", "es": "3 · Grúa torre en obra", "nl": "3 · Torenkraan op de bouwplaats"},
		"desc": {"en": "Slewing, radius, blind lifts and taking direction from a signaller.",
			"es": "Giro, radio, izados a ciegas y trabajar siguiendo a un señalista.",
			"nl": "Zwenken, vlucht, blinde hijsklussen en werken met een seingever."},
	},
	"mobile_advanced": {
		"order": 4,
		"name": {"en": "4 · Mobile crane, full chart", "es": "4 · Grúa móvil, tabla completa", "nl": "4 · Mobiele kraan, volledige tabel"},
		"desc": {"en": "Telescoping under load moment, stability over the side, and knowing when to refuse the lift.",
			"es": "Telescopar bajo momento de carga, estabilidad lateral y saber cuándo rechazar la maniobra.",
			"nl": "Telescoperen onder lastmoment, stabiliteit over de zijkant, en weten wanneer je nee zegt."},
	},
	"port_rail": {
		"order": 5,
		"name": {"en": "5 · Port & rail specialisation", "es": "5 · Especialización en puerto y ferrocarril", "nl": "5 · Haven & spoor specialisatie"},
		"desc": {"en": "Container handling to centimetre tolerances, and lifting inside a rail possession.",
			"es": "Manipulación de contenedores con tolerancias de centímetros e izados dentro de un bloqueo ferroviario.",
			"nl": "Containers op centimeters, en hijsen binnen een buitendienststelling."},
	},
}

const PROGRAMME_ORDER := ["basic_indoor", "street_loader", "tower_site",
	"mobile_advanced", "port_rail"]

var scenarios: Dictionary = {}      # id -> scenario dict
var order: Array = []               # ids, sorted by programme then order
var load_errors: Array = []         # human-readable problems, shown in-game


func _ready() -> void:
	reload()


func reload() -> void:
	scenarios.clear()
	order.clear()
	load_errors.clear()

	var dir := DirAccess.open(DIR)
	if dir == null:
		load_errors.append("Cannot open %s" % DIR)
		push_error("ScenarioDB: cannot open %s" % DIR)
		return

	var files: Array = []
	for f in dir.get_files():
		# Exported projects rename .json to .json.remap / .import in some
		# configurations; accept the base name either way.
		var name := f.trim_suffix(".remap")
		if name.ends_with(".json"):
			files.append(name)
	files.sort()

	for f in files:
		var parsed := _load_one(DIR + f)
		if parsed.is_empty():
			continue
		var problem := validate(parsed)
		if problem != "":
			load_errors.append("%s: %s" % [f, problem])
			push_error("ScenarioDB: %s: %s" % [f, problem])
			continue
		var id := String(parsed.id)
		if scenarios.has(id):
			load_errors.append("%s: duplicate id %s" % [f, id])
			push_error("ScenarioDB: duplicate scenario id %s" % id)
			continue
		scenarios[id] = parsed

	order = scenarios.keys()
	order.sort_custom(_sort_scenarios)


func _load_one(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		load_errors.append("unreadable: %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		load_errors.append("not a JSON object: %s" % path)
		return {}
	return parsed


func _sort_scenarios(a: String, b: String) -> bool:
	var sa: Dictionary = scenarios[a]
	var sb: Dictionary = scenarios[b]
	var pa := PROGRAMME_ORDER.find(String(sa.get("programme", "")))
	var pb := PROGRAMME_ORDER.find(String(sb.get("programme", "")))
	if pa != pb:
		return (pa if pa >= 0 else 99) < (pb if pb >= 0 else 99)
	var oa := int(sa.get("order", 999))
	var ob := int(sb.get("order", 999))
	if oa != ob:
		return oa < ob
	return a < b


## Returns "" when valid, otherwise the first problem found. Validation is
## strict about the things that would make a scenario silently unplayable:
## a machine that cannot reach the target is worse than a load error.
func validate(s: Dictionary) -> String:
	for key in ["id", "machine", "environment", "title", "briefing", "pickup", "dropoff"]:
		if not s.has(key):
			return "missing required field '%s'" % key
	if not Catalog.MACHINES.has(String(s.machine)):
		return "unknown machine '%s'" % s.machine
	if not EnvCatalog.ENVIRONMENTS.has(String(s.environment)):
		return "unknown environment '%s'" % s.environment
	if s.has("weather") and not WeatherScript.PRESETS.has(String(s.weather)):
		return "unknown weather '%s'" % s.weather
	if not Catalog.MACHINES[String(s.machine)].environments.has(String(s.environment)):
		return "machine '%s' is not available in environment '%s'" % [s.machine, s.environment]
	for zone_key in ["pickup", "dropoff"]:
		var z = s[zone_key]
		if not (z is Dictionary) or not (z.has("x") and z.has("z")):
			return "%s zone needs x and z" % zone_key
	if float(s.get("payload_kg", 0.0)) <= 0.0:
		return "payload_kg must be > 0"
	var gross := float(s.get("payload_kg", 0.0)) + float(s.get("below_hook_kg", 0.0))
	var spec: Dictionary = Catalog.MACHINES[String(s.machine)]
	# A scenario that cannot physically be completed on its own machine is a
	# content bug, and the only place it will ever be caught is right here.
	if gross > float(spec.rated_capacity_kg) and not bool(s.get("rules", {}).get("stop_work_expected", false)):
		return "gross load %.0f kg exceeds machine capacity %.0f kg and the scenario does not expect a refusal" % [gross, spec.rated_capacity_kg]
	return ""


func get_scenario(id: String) -> Dictionary:
	return scenarios.get(id, {})


func has_scenario(id: String) -> bool:
	return scenarios.has(id)


func all_ids() -> Array:
	return order.duplicate()


func ids_in_programme(programme: String) -> Array:
	var out: Array = []
	for id in order:
		if String(scenarios[id].get("programme", "")) == programme:
			out.append(id)
	return out


func programme_name(id: String) -> String:
	return LocText.pick(PROGRAMMES.get(id, {}).get("name", {}))


func programme_desc(id: String) -> String:
	return LocText.pick(PROGRAMMES.get(id, {}).get("desc", {}))


## The next scenario a learner should attempt: the first in programme order
## that `is_done` rejects. The predicate is injected rather than read from
## GameState so this module keeps no dependency on the save system — the menu
## passes `GameState.is_completed`.
func next_for_learner(is_done: Callable) -> String:
	for id in order:
		if not bool(is_done.call(id)):
			return id
	return order[0] if not order.is_empty() else ""


func next_after(id: String) -> String:
	var i := order.find(id)
	if i < 0 or i + 1 >= order.size():
		return ""
	return order[i + 1]


func title_of(id: String) -> String:
	return LocText.pick(get_scenario(id).get("title", {}))


func gross_kg(s: Dictionary) -> float:
	return float(s.get("payload_kg", 0.0)) + float(s.get("below_hook_kg", 0.0))


## Success criteria with defaults filled in, so the session never has to
## guess and every scenario is scored on the same axes.
func success_of(s: Dictionary) -> Dictionary:
	var d: Dictionary = s.get("success", {})
	return {
		"max_swing_deg": float(d.get("max_swing_deg", 6.0)),
		"dwell_s": float(d.get("dwell_s", 1.2)),
		"height_tol_m": float(d.get("height_tol_m", 1.2)),
		"placement_tol_m": float(d.get("placement_tol_m", 0.0)),
		"time_target_s": float(d.get("time_target_s", 240.0)),
		"max_collisions": int(d.get("max_collisions", 0)),
		"max_violations": int(d.get("max_violations", 0)),
	}


func rules_of(s: Dictionary) -> Dictionary:
	var d: Dictionary = s.get("rules", {})
	return {
		"no_overload": bool(d.get("no_overload", true)),
		"require_outriggers": bool(d.get("require_outriggers", true)),
		"stop_work_expected": bool(d.get("stop_work_expected", false)),
		"require_signaller": bool(d.get("require_signaller", false)),
	}
