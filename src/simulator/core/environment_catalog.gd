extends Node
## EnvironmentCatalog — the sites the machines work in.
##
## An environment supplies: ground extent and material, whether it is indoor,
## where the operator spawns, where the machine's base sits, and the hazard
## profile that scoring cares about (traffic, pedestrians, overhead lines,
## adjacent track). The geometry itself is built by the matching builder in
## `environments/`; this file is the contract between menu, builder and scoring.

const LocText := preload("res://core/loc.gd")

const HALL := "ENV-HALL"
const SITE_STREET := "ENV-SITE-STREET"
const SITE_LARGE := "ENV-SITE-LARGE"
const PORT := "ENV-PORT"
const RAILYARD := "ENV-RAILYARD"

const ORDER := [HALL, SITE_STREET, SITE_LARGE, PORT, RAILYARD]

const ENVIRONMENTS = {
	HALL: {
		"id": HALL,
		"builder": "res://environments/hall.gd",
		"indoor": true,
		"name": {"en": "Production hall, Arnhem",
			"es": "Nave de producción, Arnhem",
			"nl": "Productiehal, Arnhem"},
		"blurb": {
			"en": "Indoor bay with steel columns and a marked walkway. Sheltered from wind, but every column is something to swing a load into.",
			"es": "Nave interior con columnas de acero y un pasillo peatonal marcado. Resguardada del viento, pero cada columna es algo contra lo que golpear la carga.",
			"nl": "Binnenhal met stalen kolommen en een gemarkeerd looppad.",
		},
		"ground": {"size": Vector2(64.0, 22.0), "center": Vector2(30.0, 9.0), "material": "concrete"},
		"machine_base": Vector3(0.0, 0.0, 0.0),
		"player_spawn": Vector3(10.0, 0.1, 14.0),
		# Indoor wind is a fraction of the outdoor value: doors and vents, not
		# a sealed box. Keeps the wind lesson present without dominating.
		"wind_shelter": 0.15,
		"hazards": ["columns", "pedestrians"],
		"tier": 1,
	},
	SITE_STREET: {
		"id": SITE_STREET,
		"builder": "res://environments/street_works.gd",
		"indoor": false,
		"name": {"en": "Street works, city centre",
			"es": "Obra en calle, centro urbano",
			"nl": "Straatwerk, binnenstad"},
		"blurb": {
			"en": "A closed lane between parked cars and a pavement. Tight, overlooked by facades, and the public is a metre away behind the barriers.",
			"es": "Un carril cortado entre coches aparcados y una acera. Estrecho, encajonado entre fachadas, y el público a un metro tras las vallas.",
			"nl": "Afgesloten rijstrook tussen geparkeerde auto's en een stoep.",
		},
		"ground": {"size": Vector2(70.0, 34.0), "center": Vector2(0.0, 0.0), "material": "asphalt"},
		"machine_base": Vector3(0.0, 0.0, 0.0),
		"player_spawn": Vector3(-9.0, 0.1, 7.5),
		"wind_shelter": 0.65,
		"hazards": ["traffic", "pedestrians", "overhead_lines", "facades"],
		"tier": 2,
	},
	SITE_LARGE: {
		"id": SITE_LARGE,
		"builder": "res://environments/construction_site.gd",
		"indoor": false,
		"name": {"en": "Housing construction site",
			"es": "Obra de edificación residencial",
			"nl": "Woningbouwplaats"},
		"blurb": {
			"en": "Open site with a rising concrete frame, a rebar laydown area and a tower crane over all of it. Long radii, blind drops behind the slab.",
			"es": "Obra abierta con una estructura de hormigón en crecimiento, acopio de ferralla y una grúa torre sobre todo ello. Radios largos y descensos a ciegas tras la losa.",
			"nl": "Open bouwplaats met betonskelet, wapeningsopslag en een torenkraan.",
		},
		"ground": {"size": Vector2(110.0, 110.0), "center": Vector2(0.0, 0.0), "material": "soil"},
		"machine_base": Vector3(0.0, 0.0, 0.0),
		"player_spawn": Vector3(16.0, 0.1, 16.0),
		"wind_shelter": 1.0,
		"hazards": ["open_edges", "workers_below", "rebar", "wind_exposure"],
		"tier": 2,
	},
	PORT: {
		"id": PORT,
		"builder": "res://environments/port_terminal.gd",
		"indoor": false,
		"name": {"en": "Container terminal quay",
			"es": "Muelle de terminal de contenedores",
			"nl": "Containerterminal kade"},
		"blurb": {
			"en": "Quayside with a container stack, a moored vessel and truck lanes. Fully wind-exposed, high above the water, centimetre tolerances.",
			"es": "Muelle con pila de contenedores, buque atracado y carriles de camiones. Totalmente expuesto al viento, alto sobre el agua, tolerancias de centímetros.",
			"nl": "Kade met containerstapel, schip en vrachtwagenbanen.",
		},
		"ground": {"size": Vector2(120.0, 80.0), "center": Vector2(40.0, 10.0), "material": "concrete"},
		"machine_base": Vector3(0.0, 0.0, 0.0),
		"player_spawn": Vector3(30.0, 0.1, 34.0),
		"wind_shelter": 1.25,   # open water: more wind than the nominal, not less
		"hazards": ["quay_edge", "water", "vehicles", "wind_exposure", "suspended_over_water"],
		"tier": 3,
	},
	RAILYARD: {
		"id": RAILYARD,
		"builder": "res://environments/rail_yard.gd",
		"indoor": false,
		"name": {"en": "Rail maintenance yard",
			"es": "Base de mantenimiento ferroviario",
			"nl": "Spoorwerkplaats/emplacement"},
		"blurb": {
			"en": "Multiple tracks, sleeper and rail stacks, an overhead line mast row and an adjacent track that is NOT in the possession.",
			"es": "Varias vías, acopios de traviesas y carril, una fila de postes de catenaria y una vía contigua que NO está en el bloqueo.",
			"nl": "Meerdere sporen, dwarsliggers, bovenleidingmasten en een naastgelegen spoor buiten de buitendienststelling.",
		},
		"ground": {"size": Vector2(100.0, 46.0), "center": Vector2(40.0, 0.0), "material": "ballast"},
		"machine_base": Vector3(0.0, 0.0, 0.0),
		"player_spawn": Vector3(24.0, 0.1, 10.0),
		"wind_shelter": 1.0,
		"hazards": ["adjacent_track", "overhead_line", "trackside_workers", "possession_limits"],
		"tier": 3,
	},
}


func get_env(id: String) -> Dictionary:
	return ENVIRONMENTS.get(id, ENVIRONMENTS[HALL])


func has_env(id: String) -> bool:
	return ENVIRONMENTS.has(id)


func all_ids() -> Array:
	return ORDER.duplicate()


func display_name(id: String) -> String:
	return LocText.pick(get_env(id).get("name", {}))


func is_indoor(id: String) -> bool:
	return bool(get_env(id).get("indoor", false))


## Wind actually reaching the load in this environment: outdoor sites can even
## amplify (open quay), a hall damps it to a draught.
func wind_shelter(id: String) -> float:
	return float(get_env(id).get("wind_shelter", 1.0))


func builder_path(id: String) -> String:
	return String(get_env(id).get("builder", "res://environments/hall.gd"))
