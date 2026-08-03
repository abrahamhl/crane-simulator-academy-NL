extends Node
## ControlScheme — ONE definition of what every key does, for every machine.
##
## This module exists because the previous build failed the most basic test a
## simulator has: the player could not work out how to pick up the pendant and
## drive the crane. The cause was that the bindings lived in four places
## (input_config, the HUD overlay, a .bat file's echo lines and a loc string)
## and none of them was authoritative. Here they are declared once and every
## consumer — the input map, the live key overlay, the F1 reference card, the
## tutorial and the printed control card — reads from this table. If a binding
## changes, everything that teaches it changes with it, or nothing does.
##
## DESIGN RULE — the same gesture means the same thing on every machine:
##     W / S   reach OUT / IN      (bridge travel, jib trolley, telescope)
##     A / D   swing LEFT / RIGHT  (cross-travel trolley, or slew)
##     R / F   hoist RAISE / LOWER (R = raise, F = fall) — identical everywhere
##     T / G   boom UP / DOWN      (luff, on machines that have a boom)
##     Q / E   travel BACK / FWD   (only machines that travel *and* slew)
##     SHIFT   creep / fine mode
##     SPACE   ALL STOP
## A learner who has driven the workshop crane already knows two thirds of the
## mobile crane's controls. That transfer is the point.

## axis -> [negative_action, positive_action]. Positive is the direction named
## first in the label ("out", "right", "raise", "up", "forward").
const AXIS_ACTIONS := {
	"travel_primary": ["prim_neg", "prim_pos"],   # W / S  (mapped per class)
	"lateral":        ["lat_neg", "lat_pos"],     # A / D
	"hoist":          ["hoist_up", "hoist_down"], # R / F
	"luff":           ["luff_down", "luff_up"],   # G / T
	"travel_extra":   ["trav_neg", "trav_pos"],   # Q / E
}

## Which rig axis each control pair drives, per machine class, plus the label
## the HUD and the reference card print for it.
const CLASS_MAP := {
	MachineCatalog.CLASS_OVERHEAD: {
		"travel_primary": {"axis": "travel", "keys": ["W", "S"],
			"label": {"en": "Bridge forward / back", "es": "Puente adelante / atrás", "nl": "Brug vooruit / achteruit"}},
		"lateral": {"axis": "trolley", "keys": ["A", "D"],
			"label": {"en": "Trolley left / right", "es": "Carro izquierda / derecha", "nl": "Loopkat links / rechts"}},
		"hoist": {"axis": "hoist", "keys": ["R", "F"],
			"label": {"en": "Hoist raise / lower", "es": "Izar / bajar gancho", "nl": "Hijsen / vieren"}},
	},
	MachineCatalog.CLASS_GANTRY: {
		"travel_primary": {"axis": "travel", "keys": ["W", "S"],
			"label": {"en": "Gantry along quay", "es": "Pórtico a lo largo del muelle", "nl": "Portaal langs de kade"}},
		"lateral": {"axis": "trolley", "keys": ["A", "D"],
			"label": {"en": "Trolley shore / sea side", "es": "Carro lado tierra / mar", "nl": "Loopkat wal- / zeezijde"}},
		"hoist": {"axis": "hoist", "keys": ["R", "F"],
			"label": {"en": "Spreader raise / lower", "es": "Subir / bajar spreader", "nl": "Spreader hijsen / vieren"}},
	},
	MachineCatalog.CLASS_TOWER: {
		"travel_primary": {"axis": "trolley", "keys": ["W", "S"],
			"label": {"en": "Trolley out / in (radius)", "es": "Carro fuera / dentro (radio)", "nl": "Kat uit / in (vlucht)"}},
		"lateral": {"axis": "slew", "keys": ["A", "D"],
			"label": {"en": "Slew left / right", "es": "Giro izquierda / derecha", "nl": "Zwenken links / rechts"}},
		"hoist": {"axis": "hoist", "keys": ["R", "F"],
			"label": {"en": "Hoist raise / lower", "es": "Izar / bajar gancho", "nl": "Hijsen / vieren"}},
	},
	MachineCatalog.CLASS_MOBILE: {
		"travel_primary": {"axis": "telescope", "keys": ["W", "S"],
			"label": {"en": "Telescope out / in", "es": "Telescopar fuera / dentro", "nl": "Telescoop uit / in"}},
		"lateral": {"axis": "slew", "keys": ["A", "D"],
			"label": {"en": "Slew left / right", "es": "Giro izquierda / derecha", "nl": "Zwenken links / rechts"}},
		"luff": {"axis": "luff", "keys": ["T", "G"],
			"label": {"en": "Boom up / down", "es": "Subir / bajar pluma", "nl": "Giek omhoog / omlaag"}},
		"hoist": {"axis": "hoist", "keys": ["R", "F"],
			"label": {"en": "Hoist raise / lower", "es": "Izar / bajar gancho", "nl": "Hijsen / vieren"}},
	},
	MachineCatalog.CLASS_LOADER: {
		"travel_primary": {"axis": "telescope", "keys": ["W", "S"],
			"label": {"en": "Extension out / in", "es": "Prolonga fuera / dentro", "nl": "Uitschuif uit / in"}},
		"lateral": {"axis": "slew", "keys": ["A", "D"],
			"label": {"en": "Slew left / right", "es": "Giro izquierda / derecha", "nl": "Zwenken links / rechts"}},
		"luff": {"axis": "luff", "keys": ["T", "G"],
			"label": {"en": "Boom up / down", "es": "Subir / bajar brazo", "nl": "Arm omhoog / omlaag"}},
		"hoist": {"axis": "hoist", "keys": ["R", "F"],
			"label": {"en": "Hook raise / lower", "es": "Subir / bajar gancho", "nl": "Haak omhoog / omlaag"}},
	},
	MachineCatalog.CLASS_RAILWAY: {
		"travel_extra": {"axis": "travel", "keys": ["E", "Q"],
			"label": {"en": "Travel along track", "es": "Avance por la vía", "nl": "Rijden over het spoor"}},
		"lateral": {"axis": "slew", "keys": ["A", "D"],
			"label": {"en": "Slew left / right", "es": "Giro izquierda / derecha", "nl": "Zwenken links / rechts"}},
		"luff": {"axis": "luff", "keys": ["T", "G"],
			"label": {"en": "Boom up / down", "es": "Subir / bajar pluma", "nl": "Giek omhoog / omlaag"}},
		"hoist": {"axis": "hoist", "keys": ["R", "F"],
			"label": {"en": "Hoist raise / lower", "es": "Izar / bajar gancho", "nl": "Hijsen / vieren"}},
	},
}

## Context-independent commands, printed on the reference card in this order.
const COMMANDS := [
	{"action": "fine_mode", "key": "SHIFT", "ctx": "operate",
		"label": {"en": "Creep / fine mode — hold for precision", "es": "Modo lento / fino — mantener para precisión", "nl": "Kruipmodus — ingedrukt houden"}},
	{"action": "all_stop", "key": "SPACE", "ctx": "operate",
		"label": {"en": "ALL STOP — brakes every axis", "es": "PARADA TOTAL — frena todos los ejes", "nl": "ALLES STOP — remt elke as"}},
	{"action": "outriggers_toggle", "key": "O", "ctx": "operate",
		"label": {"en": "Deploy / stow outriggers", "es": "Desplegar / recoger estabilizadores", "nl": "Stempels uit / in"}},
	{"action": "load_chart", "key": "H", "ctx": "operate",
		"label": {"en": "Load chart & lift plan", "es": "Tabla de cargas y plan de izado", "nl": "Laadtabel & hijsplan"}},
	{"action": "signal_call", "key": "B", "ctx": "operate",
		"label": {"en": "Call the signaller / banksman", "es": "Llamar al señalista", "nl": "Seingever roepen"}},
	{"action": "exit_machine", "key": "X", "ctx": "operate",
		"label": {"en": "Stop operating (put down / leave)", "es": "Dejar de operar (soltar / salir)", "nl": "Stoppen met bedienen"}},
	{"action": "sim_reset", "key": "BACKSPACE", "ctx": "operate",
		"label": {"en": "Reset the machine (not your position)", "es": "Reiniciar la máquina (no tu posición)", "nl": "Machine resetten"}},

	{"action": "move_forward", "key": "W A S D", "ctx": "foot",
		"label": {"en": "Walk", "es": "Caminar", "nl": "Lopen"}},
	{"action": "fine_mode", "key": "SHIFT", "ctx": "foot",
		"label": {"en": "Run", "es": "Correr", "nl": "Rennen"}},
	{"action": "jump", "key": "SPACE", "ctx": "foot",
		"label": {"en": "Jump", "es": "Saltar", "nl": "Springen"}},
	{"action": "interact", "key": "E", "ctx": "foot",
		"label": {"en": "Take the controls (at the marked station)", "es": "Coger los mandos (en el punto marcado)", "nl": "Bediening overnemen"}},

	{"action": "camera_cycle", "key": "TAB", "ctx": "any",
		"label": {"en": "Change camera", "es": "Cambiar cámara", "nl": "Camera wisselen"}},
	{"action": "cam_reset", "key": "C", "ctx": "any",
		"label": {"en": "Reset camera to first person", "es": "Volver a primera persona", "nl": "Terug naar eerste persoon"}},
	{"action": "help_toggle", "key": "F1", "ctx": "any",
		"label": {"en": "This control card", "es": "Esta tarjeta de controles", "nl": "Deze bedieningskaart"}},
	{"action": "map_toggle", "key": "M", "ctx": "any",
		"label": {"en": "Site map", "es": "Plano del emplazamiento", "nl": "Terreinkaart"}},
	{"action": "lang_toggle", "key": "L", "ctx": "any",
		"label": {"en": "Language EN / ES / NL", "es": "Idioma EN / ES / NL", "nl": "Taal EN / ES / NL"}},
	{"action": "wind_toggle", "key": "V", "ctx": "any",
		"label": {"en": "Wind on / off (practice)", "es": "Viento on / off (práctica)", "nl": "Wind aan / uit (oefenen)"}},
	{"action": "pause_menu", "key": "ESC", "ctx": "any",
		"label": {"en": "Pause / menu", "es": "Pausa / menú", "nl": "Pauze / menu"}},
]


## The control pairs this machine actually has, in teaching order.
func pairs_for(spec: Dictionary) -> Array:
	var cls := String(spec.get("class", MachineCatalog.CLASS_OVERHEAD))
	var map: Dictionary = CLASS_MAP.get(cls, CLASS_MAP[MachineCatalog.CLASS_OVERHEAD])
	var out: Array = []
	# Fixed order so the reference card never reshuffles between machines.
	for slot in ["travel_extra", "travel_primary", "lateral", "luff", "hoist"]:
		if not map.has(slot):
			continue
		var entry: Dictionary = map[slot]
		if not spec.get("axes", {}).has(entry.axis):
			continue     # declared in the class map but absent on this machine
		out.append({
			"slot": slot,
			"axis": String(entry.axis),
			"keys": entry.keys,
			"actions": AXIS_ACTIONS[slot],
			"label": Loc.pick(entry.label),
		})
	return out


## Reads the live input state into the {axis: command} dictionary MachineRig
## wants. This is the ONLY place raw input becomes machine motion.
func read_commands(spec: Dictionary) -> Dictionary:
	var cmds := {}
	for pair in pairs_for(spec):
		var actions: Array = pair.actions
		cmds[pair.axis] = Input.get_axis(actions[0], actions[1])
	if spec.get("needs_outriggers", false):
		cmds["outriggers"] = 0.0   # driven by the O toggle in session.gd
	return cmds


## Which physical keys light up on the HUD overlay right now, as
## [{label, action}] in the order they should be drawn.
func overlay_keys(spec: Dictionary, controlling: bool) -> Array:
	if not controlling:
		return [
			{"label": "W", "action": "move_forward"},
			{"label": "A", "action": "move_left"},
			{"label": "S", "action": "move_back"},
			{"label": "D", "action": "move_right"},
			{"label": "SHIFT", "action": "fine_mode"},
			{"label": "SPACE", "action": "jump"},
			{"label": "E", "action": "interact"},
		]
	var out: Array = []
	for pair in pairs_for(spec):
		out.append({"label": String(pair.keys[0]), "action": String(pair.actions[1])})
		out.append({"label": String(pair.keys[1]), "action": String(pair.actions[0])})
	out.append({"label": "SHIFT", "action": "fine_mode"})
	out.append({"label": "SPACE", "action": "all_stop"})
	return out


## Full reference card rows for the F1 overlay and the controls menu screen.
func reference_rows(spec: Dictionary) -> Array:
	var rows: Array = []
	rows.append({"header": Loc.t("ctrl_hdr_operate")})
	for pair in pairs_for(spec):
		rows.append({"keys": "%s / %s" % [pair.keys[0], pair.keys[1]], "text": pair.label})
	for c in COMMANDS:
		if c.ctx == "operate":
			if c.action == "outriggers_toggle" and not spec.get("needs_outriggers", false):
				continue
			rows.append({"keys": String(c.key), "text": Loc.pick(c.label)})
	rows.append({"header": Loc.t("ctrl_hdr_foot")})
	for c in COMMANDS:
		if c.ctx == "foot":
			rows.append({"keys": String(c.key), "text": Loc.pick(c.label)})
	rows.append({"header": Loc.t("ctrl_hdr_any")})
	for c in COMMANDS:
		if c.ctx == "any":
			rows.append({"keys": String(c.key), "text": Loc.pick(c.label)})
	return rows


## One-line summary strip for the bottom of the HUD.
func hint_line(spec: Dictionary, controlling: bool) -> String:
	if not controlling:
		return Loc.t("controls_walk")
	var parts := PackedStringArray()
	for pair in pairs_for(spec):
		parts.append("%s/%s %s" % [pair.keys[0], pair.keys[1], pair.label])
	parts.append("SHIFT %s" % Loc.t("fine_short"))
	parts.append("SPACE %s" % Loc.t("stop_short"))
	parts.append("X %s" % Loc.t("exit_short"))
	return "  ·  ".join(parts)
