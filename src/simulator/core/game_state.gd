extends Node
## GameState — the selection the menus make and the session then plays, plus
## the learner's persisted progress.
##
## Autoloaded. Menus WRITE the selection; the session READS it once at _ready
## and never again, so a mid-session menu change cannot half-apply. Progress
## (best scores, completed scenarios) is written to user:// after every result
## and is the only thing that survives a restart.
##
## Nothing commercial lives here: this is per-learner local play state. The
## assessment weighting and the licence-mapping that make the product sellable
## are deliberately NOT in this file (see docs/PUBLIC_VS_COMMERCIAL.md).

signal progress_changed

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 2

## --- current selection (what the next session will build) -------------------
var machine_id := "MC-OVH-05T"
var environment_id := "ENV-HALL"
var weather_id := "clear"
var scenario_id := "SC-101"
var difficulty := "standard"       # "guided" | "standard" | "assessment"
var free_practice := false          # no objective, no scoring, nothing to fail

## --- persisted profile ------------------------------------------------------
var results: Dictionary = {}        # scenario_id -> best result dict
var seen_tutorials: Dictionary = {} # tutorial id -> true
var total_sessions := 0
var settings: Dictionary = {
	"language": 0,
	"mouse_sensitivity": 1.0,
	"invert_y": false,
	"master_volume": 0.8,
	"show_key_overlay": true,
	"show_ghost_path": true,
	"units_metric": true,
}

## Difficulty presets. "guided" is not easy mode with the physics turned down —
## the machine behaves identically. What changes is how much help is on
## screen. A learner who passes on guided has still flown the same crane.
const DIFFICULTY = {
	"guided": {
		"name": {"en": "Guided", "es": "Guiado", "nl": "Begeleid"},
		"desc": {
			"en": "Every prompt, arrows to the target, the load chart always open. Mistakes are explained, not punished.",
			"es": "Todos los avisos, flechas hacia el objetivo y la tabla de cargas siempre abierta. Los errores se explican, no se castigan.",
			"nl": "Alle aanwijzingen, pijlen naar het doel, laadtabel altijd zichtbaar.",
		},
		"show_hints": true, "show_path": true, "show_chart": true,
		"time_pressure": false, "fail_on_violation": false, "score_multiplier": 0.8,
	},
	"standard": {
		"name": {"en": "Standard", "es": "Estándar", "nl": "Standaard"},
		"desc": {
			"en": "Prompts on request, target marked, warnings when you approach a limit. The normal way to practise.",
			"es": "Avisos bajo petición, objetivo marcado y advertencias al acercarte a un límite. La forma normal de practicar.",
			"nl": "Aanwijzingen op verzoek, doel gemarkeerd, waarschuwingen bij limieten.",
		},
		"show_hints": true, "show_path": false, "show_chart": true,
		"time_pressure": true, "fail_on_violation": false, "score_multiplier": 1.0,
	},
	"assessment": {
		"name": {"en": "Assessment", "es": "Evaluación", "nl": "Beoordeling"},
		"desc": {
			"en": "Briefing only. No hints, no path, chart on request. A safety violation ends the run — as it would end a real test.",
			"es": "Solo el briefing. Sin pistas ni trazado, tabla bajo petición. Una infracción de seguridad termina la prueba, como en un examen real.",
			"nl": "Alleen de briefing. Geen hints. Een veiligheidsovertreding beëindigt de rit.",
		},
		"show_hints": false, "show_path": false, "show_chart": false,
		"time_pressure": true, "fail_on_violation": true, "score_multiplier": 1.25,
	},
}

const DIFFICULTY_ORDER := ["guided", "standard", "assessment"]


func _ready() -> void:
	load_profile()
	# GameState owns persistence, so it listens for the language change rather
	# than Loc reaching into the save file.
	Loc.language_changed.connect(_on_language_changed)


func _on_language_changed(new_lang: int) -> void:
	settings["language"] = new_lang
	save_profile()


func difficulty_config() -> Dictionary:
	return DIFFICULTY.get(difficulty, DIFFICULTY["standard"])


func difficulty_name(id: String) -> String:
	return Loc.pick(DIFFICULTY.get(id, DIFFICULTY["standard"]).get("name", {}))


## Applies a scenario's own machine/environment/weather requirements to the
## selection, so picking a scenario from the menu always produces a runnable
## combination even if the learner's last free-practice choice was unrelated.
func select_scenario(scenario: Dictionary) -> void:
	scenario_id = String(scenario.get("id", scenario_id))
	if scenario.has("machine"):
		machine_id = String(scenario.machine)
	if scenario.has("environment"):
		environment_id = String(scenario.environment)
	if scenario.has("weather"):
		weather_id = String(scenario.weather)
	free_practice = false


func select_free_practice(p_machine: String, p_env: String, p_weather: String) -> void:
	machine_id = p_machine
	environment_id = p_env
	weather_id = p_weather
	scenario_id = ""
	free_practice = true


# --- progress ----------------------------------------------------------------

func best_result(id: String) -> Dictionary:
	return results.get(id, {})


func is_completed(id: String) -> bool:
	return bool(best_result(id).get("passed", false))


func completed_count() -> int:
	var n := 0
	for id in results:
		if bool(results[id].get("passed", false)):
			n += 1
	return n


## Records a result, keeping the BEST attempt rather than the latest: a
## learner who passes then experiments should not lose the pass.
func record_result(id: String, result: Dictionary) -> void:
	if id.is_empty():
		return
	total_sessions += 1
	var prev: Dictionary = results.get(id, {})
	var better := prev.is_empty()
	if not better:
		var was_passed := bool(prev.get("passed", false))
		var now_passed := bool(result.get("passed", false))
		if now_passed and not was_passed:
			better = true
		elif now_passed == was_passed:
			better = float(result.get("points", 0.0)) > float(prev.get("points", 0.0))
	if better:
		results[id] = result.duplicate(true)
	save_profile()
	progress_changed.emit()


func mark_tutorial_seen(id: String) -> void:
	if not seen_tutorials.has(id):
		seen_tutorials[id] = true
		save_profile()


func has_seen_tutorial(id: String) -> bool:
	return seen_tutorials.has(id)


# --- persistence -------------------------------------------------------------

func save_profile() -> void:
	var data := {
		"version": SAVE_VERSION,
		"results": results,
		"seen_tutorials": seen_tutorials,
		"total_sessions": total_sessions,
		"settings": settings,
		"last": {
			"machine": machine_id, "environment": environment_id,
			"weather": weather_id, "difficulty": difficulty,
		},
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	# A profile from an older save version is read for what still applies
	# rather than discarded — losing a learner's progress to a schema bump
	# would be a worse bug than a missing field.
	results = parsed.get("results", {})
	seen_tutorials = parsed.get("seen_tutorials", {})
	total_sessions = int(parsed.get("total_sessions", 0))
	var s: Dictionary = parsed.get("settings", {})
	for k in s:
		if settings.has(k):
			settings[k] = s[k]
	var last: Dictionary = parsed.get("last", {})
	if MachineCatalog.has_machine(String(last.get("machine", ""))):
		machine_id = String(last.machine)
	if EnvironmentCatalog.has_env(String(last.get("environment", ""))):
		environment_id = String(last.environment)
	if Weather.has_weather(String(last.get("weather", ""))):
		weather_id = String(last.weather)
	if DIFFICULTY.has(String(last.get("difficulty", ""))):
		difficulty = String(last.difficulty)
	Loc.lang = int(settings.get("language", 0))


func reset_progress() -> void:
	results.clear()
	seen_tutorials.clear()
	total_sessions = 0
	save_profile()
	progress_changed.emit()
