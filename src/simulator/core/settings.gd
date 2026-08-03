extends Node
## AppSettings — central tunables shared by the session, the builders and the
## tests, so they can never drift apart. Constants only; anything a player can
## change at runtime lives in GameState.settings instead.

# --- fixed-step simulation ---------------------------------------------------

const DT := 1.0 / 60.0
const CABLE_SUBSTEPS := 2         # cable sim runs at 120 Hz inside the 60 Hz tick

# --- load / cable defaults (a scenario overrides mass and size) --------------

const LOAD_DRAG_CD := 1.2
const LOAD_DRAG_AREA_M2 := 2.0
const LOAD_MASS_KG := 500.0       # legacy default, still used by the unit tests
const START_CABLE_LEN_M := 5.0

## Restitution/damping for the load bouncing off ground or structure.
const IMPACT_RESTITUTION := 0.3
const IMPACT_DAMPING := 0.8

## Radius (m) around the load's centre counted as a near-miss/caution zone —
## deliberately LARGER than the load's own collision box, per
## .claude/rules/simulation-physics.md ("separate physical collision volumes
## from safety/near-miss volumes"). Entering it cautions; touching the load
## itself is always a violation.
const LOAD_SAFETY_RADIUS_M := 2.0

# --- wind --------------------------------------------------------------------

const WIND_SEED := 20260717
const WIND_DIR_DEG := 90.0        # blows toward +Z
const WIND_SPEED_MS := 6.0
const WIND_GUST_SIGMA := 1.5
const WIND_GUST_TAU_S := 3.0

# --- player ------------------------------------------------------------------

const PLAYER_EYE_HEIGHT := 1.65
const PLAYER_RADIUS := 0.35
const PLAYER_WALK_SPEED := 2.2    # m/s — realistic site walking pace
const PLAYER_SPRINT_SPEED := 4.5
const PLAYER_JUMP_VELOCITY := 4.2
const PLAYER_GRAVITY := 9.80665
const MOUSE_SENSITIVITY := 0.0025
const PITCH_LIMIT_DEG := 80.0

# --- machine access ----------------------------------------------------------

## Radius around a control position within which E takes the controls.
const ACCESS_RADIUS_M := 2.2

## Legacy slice-001 constants. The unit tests for MachineAccess and the
## original overhead rig still assert against these, so they stay fixed even
## though the hall builder now derives its own control position.
const ACCESS_POINT := Vector3(1.0, 0.0, 9.0)
const PLAYER_SPAWN := Vector3(10.0, 0.1, 14.0)
const PICKUP_ZONE := {"x": 10.0, "z": 9.0, "radius": 1.8, "color": Color(0.95, 0.85, 0.1, 0.55)}
const DROPOFF_ZONE := {"x": 22.0, "z": 5.0, "radius": 1.8, "color": Color(0.15, 0.55, 0.95, 0.55)}
const SWING_SUCCESS_DEG := 2.0
const PICKUP_HEIGHT_TOLERANCE_M := 1.2
const DWELL_TIME_S := 1.0

## Selectable load masses for free practice (kg).
const SELECTABLE_MASSES_KG := [250.0, 500.0, 1000.0, 2000.0, 5000.0, 12000.0]

# --- machine masses used by the stability model ------------------------------
## Counterweighted operating mass acting at the slew centre, in kg. Training
## figures consistent with each machine's rated class — NOT manufacturer data.
const MACHINE_MASS_KG := {
	"MC-MOB-40T": 42000.0,
	"MC-LDR-8TM": 14000.0,
	"MC-RAIL-25T": 68000.0,
	"MC-TWR-45M": 240000.0,
	"MC-STS-CONT": 900000.0,
	"MC-OVH-05T": 1e9,     # structurally supported: stability never binds
	"MC-OVH-16T": 1e9,
}

# --- scoring -----------------------------------------------------------------

## Points deducted per event. Published here rather than buried in the scorer
## so an instructor can see exactly what the number means. The *weighting
## philosophy* used in the commercial assessment product is separate and is
## not in this repository (see docs/PUBLIC_VS_COMMERCIAL.md).
const PENALTY = {
	"collision": 25.0,
	"violation": 40.0,
	"near_miss": 8.0,
	"overload_second": 6.0,
	"unstable_second": 6.0,
	"over_wind_second": 3.0,
}
const BASE_POINTS := 1000.0
const PASS_POINTS := 600.0


func machine_mass_kg(machine_id: String) -> float:
	return float(MACHINE_MASS_KG.get(machine_id, 50000.0))
