extends Node
## MachineCatalog — the data definition of every operable machine.
##
## One entry per machine. Nothing here is scene data: a spec is a plain
## Dictionary describing which AXES the machine has, their limits and speeds,
## its rated load chart and which control scheme drives it. MachineRig turns a
## spec into kinematics; SessionBuilder turns it into geometry; ControlScheme
## turns it into key bindings and HUD labels. Adding a crane therefore means
## adding one entry here plus one visual builder — not a new simulator.
##
## AXIS VOCABULARY (all machines are described with these six):
##   travel    linear, along world X   — bridge/gantry/rail-bogie travel, m
##   trolley   linear                  — across the bridge (Z) for overhead and
##                                       gantry; ALONG THE JIB (radius) for a
##                                       tower crane, m
##   slew      rotation about world Y  — superstructure rotation, degrees
##   luff      boom elevation          — angle above horizontal, degrees
##   telescope boom extension          — total boom length, m
##   hoist     rope payout             — cable length below the head, m
## A machine simply omits the axes it does not have.
##
## CAPACITY DATA IS A TRAINING ENVELOPE, NOT MANUFACTURER DATA.
## Per the project rules: no real machine's certified load chart is reproduced
## here and none is implied. These are plausible, internally-consistent
## envelopes shaped like real ones so the *skill* of reading a chart and
## respecting a load moment transfers. `chart_source` says so on every entry
## and the UI prints it. Never present these numbers as a rated capacity for
## any actual crane.

const LocText := preload("res://core/loc.gd")

const CLASS_OVERHEAD := "overhead"
const CLASS_GANTRY := "gantry"
const CLASS_TOWER := "tower"
const CLASS_MOBILE := "mobile"
const CLASS_RAILWAY := "railway"
const CLASS_LOADER := "loader"

const TRAINING_ENVELOPE := "training_envelope_not_manufacturer_data"

## Difficulty tiers gate which machines a learner should attempt first. They
## are advisory ordering, not a lock — Free Practice ignores them.
const TIER_BASIC := 1
const TIER_INTERMEDIATE := 2
const TIER_ADVANCED := 3

const MACHINES := {
	"MC-OVH-05T": {
		"id": "MC-OVH-05T",
		"class": CLASS_OVERHEAD,
		"tier": TIER_BASIC,
		"name": {
			"en": "Overhead travelling crane 5 t",
			"es": "Puente grúa 5 t",
			"nl": "Bovenloopkraan 5 t",
		},
		"blurb": {
			"en": "Pendant-operated workshop bridge crane. Two straight axes and a hoist — the machine every indoor lifting course starts on.",
			"es": "Puente grúa de taller con mando colgante. Dos ejes rectos y un polipasto: la máquina con la que empieza todo curso de elevación en interior.",
			"nl": "Bovenloopkraan met hangbediening. Twee rechte assen en een hijswerk.",
		},
		"control_scheme": "pendant",
		"rated_capacity_kg": 5000.0,
		"environments": ["ENV-HALL"],
		"axes": {
			"travel":  {"min": 2.0,  "max": 58.0, "speed": 0.80, "accel": 0.50},
			"trolley": {"min": 1.5,  "max": 16.5, "speed": 0.60, "accel": 0.50},
			"hoist":   {"min": 1.2,  "max": 8.00, "speed": 0.35, "accel": 0.45},
		},
		"geometry": {"head_height": 9.0, "home": {"travel": 10.0, "trolley": 9.0, "hoist": 5.0}},
		# Constant-capacity machine: an overhead crane's rating does not fall
		# off with position. Single point => LoadChart returns it everywhere.
		"load_chart": [[0.0, 5000.0]],
		"chart_source": TRAINING_ENVELOPE,
	},

	"MC-OVH-16T": {
		"id": "MC-OVH-16T",
		"class": CLASS_OVERHEAD,
		"tier": TIER_INTERMEDIATE,
		"name": {
			"en": "Overhead travelling crane 16 t",
			"es": "Puente grúa 16 t",
			"nl": "Bovenloopkraan 16 t",
		},
		"blurb": {
			"en": "Heavy hall crane. Same controls as the 5 t but far more inertia — starts and stops must be planned, not reacted to.",
			"es": "Puente pesado de nave. Mismos mandos que el de 5 t pero con mucha más inercia: los arranques y paradas se planifican, no se improvisan.",
			"nl": "Zware hallenkraan. Zelfde bediening, veel meer traagheid.",
		},
		"control_scheme": "pendant",
		"rated_capacity_kg": 16000.0,
		"environments": ["ENV-HALL"],
		"axes": {
			"travel":  {"min": 2.0,  "max": 58.0, "speed": 0.55, "accel": 0.22},
			"trolley": {"min": 1.5,  "max": 16.5, "speed": 0.42, "accel": 0.20},
			"hoist":   {"min": 1.2,  "max": 8.00, "speed": 0.22, "accel": 0.25},
		},
		"geometry": {"head_height": 9.0, "home": {"travel": 10.0, "trolley": 9.0, "hoist": 5.0}},
		"load_chart": [[0.0, 16000.0]],
		"chart_source": TRAINING_ENVELOPE,
	},

	"MC-TWR-45M": {
		"id": "MC-TWR-45M",
		"class": CLASS_TOWER,
		"tier": TIER_INTERMEDIATE,
		"name": {
			"en": "Tower crane, 45 m jib",
			"es": "Grúa torre, pluma 45 m",
			"nl": "Torenkraan, 45 m giek",
		},
		"blurb": {
			"en": "Flat-top saddle-jib tower crane. Slew and trolley radius replace straight travel; capacity falls as the trolley runs out along the jib.",
			"es": "Grúa torre de pluma horizontal. La rotación y el radio del carro sustituyen al avance recto; la capacidad cae según el carro se aleja por la pluma.",
			"nl": "Torenkraan met horizontale giek. Zwenken en katradius vervangen recht rijden.",
		},
		"control_scheme": "cabin_tower",
		"rated_capacity_kg": 8000.0,
		"environments": ["ENV-SITE-LARGE"],
		"axes": {
			"slew":    {"min": -180.0, "max": 180.0, "speed": 8.0,  "accel": 4.0, "wraps": true},
			"trolley": {"min": 3.5,    "max": 45.0,  "speed": 0.90, "accel": 0.45},
			"hoist":   {"min": 1.0,    "max": 44.0,  "speed": 0.85, "accel": 0.60},
		},
		"geometry": {"head_height": 42.0, "home": {"slew": 0.0, "trolley": 18.0, "hoist": 24.0}},
		# Classic saddle-jib curve: full capacity to the "sweet spot" radius,
		# then hyperbolic decay as the load moment limit binds.
		"load_chart": [
			[3.5, 8000.0], [12.0, 8000.0], [18.0, 5300.0], [24.0, 3900.0],
			[30.0, 3000.0], [36.0, 2450.0], [40.0, 2150.0], [45.0, 1850.0],
		],
		"chart_source": TRAINING_ENVELOPE,
	},

	"MC-MOB-40T": {
		"id": "MC-MOB-40T",
		"class": CLASS_MOBILE,
		"tier": TIER_ADVANCED,
		"name": {
			"en": "Mobile telescopic crane 40 t",
			"es": "Grúa móvil telescópica 40 t",
			"nl": "Mobiele telescoopkraan 40 t",
		},
		"blurb": {
			"en": "Road-going telescopic crane on outriggers. Slew, luff and telescope all change the radius at once — the hardest chart to keep in your head.",
			"es": "Grúa telescópica de carretera sobre estabilizadores. Giro, elevación y telescopado cambian el radio a la vez: la tabla de cargas más difícil de mantener en la cabeza.",
			"nl": "Mobiele telescoopkraan op stempels. Zwenken, hijsen en telescoperen wijzigen tegelijk de vlucht.",
		},
		"control_scheme": "cabin_mobile",
		"rated_capacity_kg": 40000.0,
		"environments": ["ENV-SITE-STREET", "ENV-SITE-LARGE"],
		"needs_outriggers": true,
		"axes": {
			"slew":      {"min": -180.0, "max": 180.0, "speed": 6.0,  "accel": 3.0, "wraps": true},
			"luff":      {"min": 4.0,    "max": 78.0,  "speed": 3.5,  "accel": 2.0},
			"telescope": {"min": 10.5,   "max": 34.0,  "speed": 0.65, "accel": 0.35},
			"hoist":     {"min": 1.0,    "max": 32.0,  "speed": 0.70, "accel": 0.50},
		},
		"geometry": {"pivot_height": 2.6, "home": {"slew": 0.0, "luff": 62.0, "telescope": 10.5, "hoist": 6.0}},
		# Steep mobile-crane decay: 40 t only exists at minimum radius over the
		# rear; by 26 m the load moment limit has cut it by ~95 %.
		"load_chart": [
			[3.0, 40000.0], [4.0, 33000.0], [5.0, 26000.0], [6.0, 21000.0],
			[8.0, 14500.0], [10.0, 10500.0], [12.0, 8000.0], [14.0, 6200.0],
			[16.0, 4900.0], [18.0, 3900.0], [20.0, 3100.0], [24.0, 2100.0],
			[28.0, 1400.0], [32.0, 900.0],
		],
		"chart_source": TRAINING_ENVELOPE,
		# Outrigger footprint (half-width X, half-length Z, m) used by
		# StabilityModel for the tipping lines.
		"outriggers": {"half_x": 3.6, "half_z": 3.4, "retracted_half_x": 1.3, "retracted_half_z": 3.0},
	},

	"MC-LDR-8TM": {
		"id": "MC-LDR-8TM",
		"class": CLASS_LOADER,
		"tier": TIER_BASIC,
		"name": {
			"en": "Lorry loader crane 8 tm",
			"es": "Grúa autocargante 8 tm",
			"nl": "Autolaadkraan 8 tm",
		},
		"blurb": {
			"en": "Knuckle-boom crane on a delivery lorry. Small, fast, and the machine most likely to be working beside live traffic.",
			"es": "Grúa de brazo articulado sobre camión de reparto. Pequeña, rápida y la que más veces trabaja junto al tráfico.",
			"nl": "Autolaadkraan met knikarm op een vrachtwagen. Klein, snel, vaak naast verkeer.",
		},
		"control_scheme": "ground_loader",
		"rated_capacity_kg": 3200.0,
		"environments": ["ENV-SITE-STREET"],
		"needs_outriggers": true,
		"axes": {
			"slew":      {"min": -180.0, "max": 180.0, "speed": 9.0,  "accel": 5.0, "wraps": true},
			"luff":      {"min": -8.0,   "max": 72.0,  "speed": 6.0,  "accel": 4.0},
			"telescope": {"min": 3.2,    "max": 9.60,  "speed": 0.55, "accel": 0.40},
			"hoist":     {"min": 0.6,    "max": 9.00,  "speed": 0.55, "accel": 0.50},
		},
		"geometry": {"pivot_height": 2.1, "home": {"slew": 0.0, "luff": 55.0, "telescope": 3.2, "hoist": 3.0}},
		# 8 tm rating class: capacity ~= 8000 kg*m / radius, tapered at the ends.
		"load_chart": [
			[2.5, 3200.0], [3.0, 2650.0], [4.0, 2000.0], [5.0, 1600.0],
			[6.0, 1330.0], [7.0, 1140.0], [8.0, 1000.0], [9.6, 830.0],
		],
		"chart_source": TRAINING_ENVELOPE,
		"outriggers": {"half_x": 2.6, "half_z": 1.8, "retracted_half_x": 1.1, "retracted_half_z": 1.8},
	},

	"MC-STS-CONT": {
		"id": "MC-STS-CONT",
		"class": CLASS_GANTRY,
		"tier": TIER_ADVANCED,
		"name": {
			"en": "Ship-to-shore container gantry",
			"es": "Grúa pórtico portacontenedores",
			"nl": "Containerkraan (ship-to-shore)",
		},
		"blurb": {
			"en": "Quayside container crane with a twistlock spreader. Long straight axes, huge masses and a target you must hit within centimetres.",
			"es": "Grúa de muelle para contenedores con spreader. Ejes rectos largos, masas enormes y un objetivo que hay que acertar al centímetro.",
			"nl": "Kadekraan met spreader. Lange assen, grote massa's, centimeterwerk.",
		},
		"control_scheme": "cabin_gantry",
		"rated_capacity_kg": 41000.0,
		"environments": ["ENV-PORT"],
		"has_spreader": true,
		"axes": {
			"travel":  {"min": 6.0,   "max": 78.0, "speed": 1.10, "accel": 0.35},
			# Negative trolley is the WATERSIDE reach out over the vessel;
			# positive is the backreach over the yard and the truck lanes.
			# The quay edge sits at z = 0, which is why the range straddles it.
			"trolley": {"min": -26.0, "max": 44.0, "speed": 1.60, "accel": 0.70},
			"hoist":   {"min": 1.5,   "max": 34.0, "speed": 1.40, "accel": 0.90},
		},
		"geometry": {"head_height": 38.0, "home": {"travel": 30.0, "trolley": 16.0, "hoist": 20.0}},
		"load_chart": [[0.0, 41000.0]],
		"chart_source": TRAINING_ENVELOPE,
	},

	"MC-RAIL-25T": {
		"id": "MC-RAIL-25T",
		"class": CLASS_RAILWAY,
		"tier": TIER_ADVANCED,
		"name": {
			"en": "Rail-mounted slewing crane 25 t",
			"es": "Grúa ferroviaria giratoria 25 t",
			"nl": "Spoorkraan, zwenkbaar 25 t",
		},
		"blurb": {
			"en": "Track-bound lattice-boom crane for permanent-way work. Travels only on rails, slews over a narrow base, and everything happens inside a possession window.",
			"es": "Grúa de celosía sobre vía para trabajos de infraestructura ferroviaria. Solo avanza por el carril, gira sobre una base estrecha y todo ocurre dentro de una ventana de trabajo.",
			"nl": "Spoorgebonden vakwerkkraan voor baanwerk. Rijdt alleen over spoor, zwenkt op een smalle basis.",
		},
		"control_scheme": "cabin_railway",
		"rated_capacity_kg": 25000.0,
		"environments": ["ENV-RAILYARD"],
		"needs_outriggers": true,
		"axes": {
			"travel": {"min": 4.0,    "max": 76.0,  "speed": 0.60, "accel": 0.25},
			"slew":   {"min": -180.0, "max": 180.0, "speed": 5.0,  "accel": 2.5, "wraps": true},
			"luff":   {"min": 18.0,   "max": 80.0,  "speed": 2.6,  "accel": 1.6},
			"hoist":  {"min": 1.0,    "max": 26.0,  "speed": 0.60, "accel": 0.45},
		},
		# Fixed lattice boom: no telescope axis, so radius comes from luff alone.
		"geometry": {"pivot_height": 3.2, "boom_length": 22.0, "home": {"travel": 30.0, "slew": 0.0, "luff": 66.0, "hoist": 8.0}},
		"load_chart": [
			[3.5, 25000.0], [5.0, 19500.0], [7.0, 14000.0], [9.0, 10500.0],
			[11.0, 8200.0], [13.0, 6600.0], [15.0, 5400.0], [18.0, 4100.0],
			[21.0, 3200.0],
		],
		"chart_source": TRAINING_ENVELOPE,
		"outriggers": {"half_x": 2.2, "half_z": 3.8, "retracted_half_x": 1.4, "retracted_half_z": 3.8},
	},
}

## Menu ordering: basic machines first so a new learner meets the pendant
## crane before the mobile telescopic.
const ORDER := ["MC-OVH-05T", "MC-LDR-8TM", "MC-OVH-16T", "MC-TWR-45M",
	"MC-MOB-40T", "MC-RAIL-25T", "MC-STS-CONT"]


func get_spec(id: String) -> Dictionary:
	return MACHINES.get(id, MACHINES["MC-OVH-05T"])


func has_machine(id: String) -> bool:
	return MACHINES.has(id)


func all_ids() -> Array:
	# Guards against ORDER and MACHINES drifting apart when a machine is added.
	var out: Array = []
	for id in ORDER:
		if MACHINES.has(id):
			out.append(id)
	for id in MACHINES:
		if not out.has(id):
			out.append(id)
	return out


func ids_for_environment(env_id: String) -> Array:
	var out: Array = []
	for id in all_ids():
		if MACHINES[id].environments.has(env_id):
			out.append(id)
	return out


func has_axis(spec: Dictionary, axis: String) -> bool:
	return spec.get("axes", {}).has(axis)


func display_name(spec: Dictionary) -> String:
	return LocText.pick(spec.get("name", {}))
