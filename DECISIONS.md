# Decision Log

Use this append-only template:

## DEC-000 — Title
- Date:
- Status: proposed | accepted | superseded
- Context:
- Evidence:
- Options considered:
- Decision:
- Why:
- Consequences:
- Risks:
- Reversal trigger:
- Files/tests affected:

## DEC-001 — Project hooks run Python via uv
- Date: 2026-07-17
- Status: accepted
- Context: `.claude/settings.json` hooks invoked bare `python`; system Python is absent on this machine, so guard/log hooks failed silently on every tool call.
- Evidence: `uv 0.11.11` present; WORKLOG 2026-07-12 toolchain audit.
- Options considered: install system Python; keep broken hooks; uv-managed interpreter.
- Decision: hook commands use `uv run --no-project python`.
- Why: zero-install, matches the toolchain policy already recorded in the worklog.
- Consequences: hooks only activate when a session is opened at the repo root (see KI-001).
- Risks: uv upgrade changing interpreter resolution (low).
- Reversal trigger: system Python becomes a managed prerequisite.
- Files/tests affected: `.claude/settings.json`.

## DEC-002 — Slice 001 scene is built procedurally; input map registered in code
- Date: 2026-07-17
- Status: accepted
- Context: `project.godot` referenced a main scene and three autoloads that did not exist. A physics proof must be reviewable and headless-verifiable.
- Evidence: recovery audit 2026-07-17; headless selftest passes (logs/SELFTEST_RESULTS.json).
- Options considered: editor-authored .tscn node trees; procedural construction from one script.
- Decision: `main.tscn` holds a single root node + script; all geometry, HUD, camera and the InputMap are created in code (`main.gd`, `core/input_config.gd`). The crane starts unpowered and a 3-item pre-use inspection (keys 1–3) must be completed before the rig accepts motion commands.
- Why: everything diffable/reviewable as text, deterministic, no hidden editor state, testable headless; unpowered start enforces the safety-first rule at the scene layer.
- Consequences: art passes later will introduce authored scenes; the rig module keeps `powered=true` as its own default, so every scene must explicitly set `powered=false` at spawn (KI-003).
- Risks: procedural visuals stay placeholder-grade (accepted for a proof).
- Reversal trigger: first visual-fidelity milestone.
- Files/tests affected: `src/simulator/slice_overhead/*`, `src/simulator/core/{loc,settings,input_config}.gd`.

## DEC-003 — Wind sequence always advances; the toggle only gates application
- Date: 2026-07-17
- Status: accepted
- Context: wind must be deterministic per seed, and reset must reproduce identical trajectories regardless of when the operator toggles wind.
- Evidence: `reset_deterministic` and `zero_wind_deterministic` tests pass with identical MD5 trajectory hashes across independent process runs.
- Options considered: step the RNG only while enabled; always-step + conditional application.
- Decision: `wind_model.step()` runs every physics tick; the toggle selects whether the vector is applied to the load.
- Why: wind state at time t is a pure function of (seed, t), independent of toggle history — the strongest reproducibility guarantee for training debriefs.
- Consequences: toggling wind ON at the same tick always yields the same gusts.
- Risks: none identified.
- Reversal trigger: multi-source weather system replacing the single OU model.
- Files/tests affected: `slice_overhead/main.gd`, `tests/selftest_driver.gd`, `tests/module_tests.gd`.

## DEC-004 — Two-tier verification: pure-module tests + in-scene selftest driver
- Date: 2026-07-17
- Status: accepted
- Context: "files created" is not success; the scene must be proven to run and respond headlessly, with results on disk.
- Evidence: `logs/MODULE_TEST_RESULTS.json` (7/7), `logs/SELFTEST_RESULTS.json` (16/16), process exit codes 0.
- Options considered: manual playtesting only; external test framework (GUT); built-in drivers.
- Decision: tier 1 — `tests/module_tests.gd` (SceneTree script, no scene/autoloads) validates pendulum period, determinism, wind displacement, NaN safety. Tier 2 — `tests/selftest_driver.gd`, instantiated by `main.gd` only under `-- --selftest`, drives the real InputMap actions tick-by-tick through the real scene and exits 0/1.
- Why: no third-party dependency; both tiers are CI-able commands with machine-readable output.
- Consequences: discrete key handling in `main.gd` uses explicit edge detection (`_edge()`), which works identically for hardware keys and `Input.action_press` injection.
- Risks: selftest tick schedules must respect drive settle times (caught once, fixed; see TEST_LOG).
- Reversal trigger: adoption of a project-wide test framework in a later phase.
- Files/tests affected: `src/simulator/tests/*`, `slice_overhead/main.gd`.

## DEC-005 — HUD gains Spanish; default pairing becomes EN/ES, not EN/NL
- Date: 2026-07-27
- Status: accepted
- Context: the user (Spanish-speaking) opened slice 001 and could not read the HUD, which shipped English/Dutch only — a defect against `01_MASTER_PROMPT_V2.md`'s explicit "English first, Spanish literal beside it, Dutch preserved in parentheses" rule, not a new feature request.
- Evidence: user screenshot showing an unreadable HUD; master prompt §project mission.
- Options considered: add Spanish as a third equal-weight language; make EN/ES the default pair (Dutch demoted to an explicit single-language mode).
- Decision: `core/loc.gd` entries are now `[en, es, nl]`. Combined default mode returns "EN / ES". Dutch is reachable via the `L` cycle (`EN_ES -> EN -> ES -> NL`) but no longer shown by default.
- Why: the user's understanding is the actual product goal; Dutch professional terms remain available for on-the-job vocabulary practice without cluttering the default HUD.
- Consequences: `tests/selftest_driver.gd`'s `hud_populated_bilingual` check now asserts "Cable length" + "Longitud de cable" instead of "Cable length" + "Kabellengte" — an intentional, documented change to the test's expectation, not a silently weakened check.
- Risks: none identified.
- Reversal trigger: none expected; would revisit only if Dutch-first training becomes a stated priority.
- Files/tests affected: `core/loc.gd`, `slice_overhead/main.gd`, `tests/selftest_driver.gd`.

## DEC-006 — Fixed operator cabin (pulpit), not a cab that rides the bridge
- Date: 2026-07-27
- Status: **SUPERSEDED by DEC-014 (same day)** — the user, drawing on real factory lifting experience, corrected this: this overhead crane class is pendant-operated from the floor, not cabin-operated. Kept for the historical record; do not build against this decision.
- Context: the user asked for a first-person player who walks to the machine, climbs in, and operates it — matching `01_MASTER_PROMPT_V2.md` §6 "Access and cabin entry" and §8 "cab/first-person", neither of which was implemented before this session.
- Evidence: real factory overhead cranes are commonly operated either from a pendant control walking the floor or from a fixed elevated pulpit near one end of the runway — both keep the operator's access point static, unlike a mobile/tower crane's cab which travels with the machine.
- Options considered: (a) a fixed pulpit with a static ladder; (b) a cab physically mounted on the moving trolley, requiring a ladder that also moves.
- Decision: (a) — a fixed booth + ladder near the runway's `x=2` end (`AppSettings.ACCESS_POINT`, `CABIN_ANCHOR`). The CABIN camera sits at that fixed point and looks toward the current hook/load position each frame.
- Why: physically correct for this machine type, and far simpler to build/verify than a moving ladder; a genuinely cab-mounted view is deferred to a machine where it is the realistic choice (e.g. a mobile crane in H4).
- Consequences: KI-007. The climb is a scripted camera/position interpolation (2.5 s), not physics-driven, since there is nothing to walk on that moves.
- Risks: none identified for this machine type.
- Reversal trigger: building a machine whose real-world cab travels with the structure.
- Files/tests affected: `core/machine_access.gd`, `core/camera_director.gd`, `slice_overhead/main.gd`, `core/settings.gd`.

## DEC-007 — R resets the machine, not the operator's position or cabin state
- Date: 2026-07-27
- Status: accepted
- Context: adding a player who can be on-foot, climbing, or in the cabin created an ambiguity the original single-state slice never had: what should the Reset key do to the *operator*, as opposed to the crane/load/wind?
- Evidence: `tests/selftest_driver.gd`'s Phase 8 (reset-determinism) presses `sim_reset` twice *while already in the cabin* and expects rig/trolley/hoist control to keep working immediately after each reset, with no re-entry step.
- Options considered: full scene reset (eject the player back outside, replay the whole approach); machine-only reset (rig/cable/wind/telemetry/objective), leaving the operator wherever they are.
- Decision: machine-only reset. `main.gd::_reset_all()` touches `rig`, `sim`, `wind_model`, `telemetry`, `objectives`, camera orbit defaults — never `access` or `player`.
- Why: matches real operator expectise ("retry the lift") and keeps the existing reset-determinism test valid without inventing an auto-re-entry mechanic. Also the more realistic reading of a training "retry" button.
- Consequences: a player who resets while on foot stays on foot; a player who resets in the cabin stays in the cabin, immediately able to keep training.
- Risks: none identified.
- Reversal trigger: a future scenario that specifically wants a full-site reset (e.g. multi-operator handover training).
- Files/tests affected: `slice_overhead/main.gd`.

## DEC-008 — Any load-to-person contact is a safety violation, not an energy threshold
- Date: 2026-07-27
- Status: accepted
- Context: the user asked for real collision — "que me pueda golpear la grúa por la inercia" — and for the detector to be unambiguous.
- Evidence: standard lifting-safety doctrine: personnel must never be positioned under or against a suspended load, regardless of its speed at the moment of contact — the risk is the mass overhead, not the current velocity.
- Options considered: kinetic-energy threshold (only count "hard" hits); unconditional violation on any contact.
- Decision: `core/load_body.gd::is_dangerous_impact()` always returns `true`. The push imparted to the player still scales with the load's speed (for game feel), but the safety-violation count does not depend on it.
- Why: teaches the correct rule (stay clear, always) instead of an artificial "it was a soft touch" exception a trainee could learn to exploit.
- Consequences: `Objectives.score().passed` requires `violations == 0` — any contact fails the lift, full stop.
- Risks: none identified.
- Reversal trigger: none expected.
- Files/tests affected: `core/load_body.gd`, `core/objectives.gd`.

## DEC-009 — Structure/floor contact is detected geometrically, not by engine collision response
- Date: 2026-07-27
- Status: accepted
- Context: the load's position is authored by `cable_load_sim.gd`'s deterministic math (per `.claude/rules/simulation-physics.md`: fixed timestep, deterministic seeds); handing the load to the physics engine as a real dynamic RigidBody3D would let the engine's own solver silently diverge from that validated math.
- Evidence: KI-004 (now resolved) — the load previously had no contact detection at all.
- Options considered: full RigidBody3D physics for the load once near a surface; keep the sim authoritative and add pure-geometry AABB/floor checks alongside it.
- Decision: the sim stays authoritative. `LoadBody.check_floor_contact()` / `check_column_contact()` are static AABB/plane checks run every tick against the sim's own `load_pos`, independent of the engine's physics step. `LoadBody` (an `Area3D`) only *detects* the player via `body_entered` — it never receives forces back.
- Why: preserves the pendulum-period validation (DEC established in Hito 0) — the load's trajectory must remain exactly what the tests verified, not whatever a general-purpose rigid-body solver produces.
- Consequences: on structure/floor contact the load is logged as a collision/violation but does not physically stop, bounce, or go slack (KI-004 residual). A real contact response is future work once it can be added without perturbing the validated free-swing math.
- Risks: none identified for this hito's scope (detection only).
- Reversal trigger: a scenario that specifically requires the load to rest on a surface (e.g. "set down" needing the cable to visibly slacken).
- Files/tests affected: `core/load_body.gd`, `core/world_builder.gd` (columns array), `slice_overhead/main.gd`.

## DEC-010 — Objectives, tutorial guidance, access state machine and collision math are pure logic, unit-tested without a scene
- Date: 2026-07-27
- Status: accepted
- Context: Hito 1 adds several new gameplay systems (pickup/deliver scoring, contextual tutorial text, approach/climb state machine, collision math). Coupling all of their verification to the heavy, timing-sensitive scene selftest would make the suite slower and more fragile than necessary.
- Evidence: `tests/module_tests.gd` tests 8-12 (objectives x2, tutorial_guide, machine_access, load_body math) all pass without instancing `main.tscn`.
- Options considered: test everything through the full scene driver; split pure state/logic into `RefCounted`/static-function modules with their own direct unit tests, reserving the scene driver for genuine integration (does the player actually walk, does the camera actually differ, does pressing a real key actually flip real state).
- Decision: the split. `core/objectives.gd`, `core/machine_access.gd`, `core/tutorial_guide.gd` are all `RefCounted`/static, taking plain values in and returning plain values out — no autoload or scene-tree dependency.
- Why: faster, more robust tests; a scoring-logic bug surfaces in milliseconds with a precise synthetic case instead of requiring a multi-thousand-tick scene replay to reach the same code path.
- Consequences: the scene selftest's new checks (`player_spawns_on_foot`, `player_blocked_by_column`, `cabin_entry_works`, `camera_modes_distinct`, `cabin_exit_works`) are deliberately kept to integration-only concerns — things that genuinely require the real `CharacterBody3D`, `Area3D` and `Camera3D`.
- Risks: none identified.
- Reversal trigger: none expected; this is the same two-tier pattern DEC-004 already established.
- Files/tests affected: `src/simulator/tests/module_tests.gd`, `src/simulator/tests/selftest_driver.gd`.

## DEC-011 — CameraDirector: HOME resolves to CABIN/WALK automatically; Tab cycles the other three views; C resets whichever view is active
- Date: 2026-07-27
- Status: accepted, **amended by DEC-014 (same day)** — DEC-014 removes the CABIN branch entirely (there is no cabin); HOME is now always first-person. The Tab-cycle / C-reset mechanism described below is unchanged.
- Context: the user asked for five distinct camera views (cabin/first-person, orbit, hook, top-down) plus the pre-existing orbit-drag-and-reset behaviour from Hito 0, which assumed the orbit camera was the ever-present default.
- Evidence: `core/camera_director.gd`; `tests/selftest_driver.gd` Phase 7/7b.
- Options considered: five independent, always-selectable modes with no special-casing; a "HOME" mode that automatically shows CABIN when in the cabin and WALK when on foot, with Tab cycling the three "away" views (ORBIT/HOOK/TOPDOWN) and C returning/resetting.
- Decision: the HOME-resolves-automatically design.
- Why: the operator's "default" view should always match their physical situation (in the cabin vs on the factory floor) without a manual step; the three away-views are for inspection/training/replay use, which is what Tab is for.
- Consequences: `cam_reset` (C) now means "reset whatever view is currently active" (orbit angles reset if in ORBIT; jump to HOME otherwise) rather than always meaning "reset the orbit camera" — Hito 0's camera test now presses `camera_cycle` (Tab) once before the orbit-drag sequence to enter ORBIT mode explicitly.
- Risks: none identified.
- Reversal trigger: none expected.
- Files/tests affected: `core/camera_director.gd`, `slice_overhead/main.gd`, `tests/selftest_driver.gd`.

## DEC-012 — Test-driven input actions must press and release on different ticks
- Date: 2026-07-27
- Status: accepted
- Context: a new selftest check (`cabin_entry_works`) initially failed — the player walked to the ladder correctly but never climbed in. Root cause: the new approach-phase code pressed and released the `interact` action within the same driver call.
- Evidence: `main.gd`'s discrete-action edge detector (`_edge()`) runs once per physics frame, and (per the node tree order established in Hito 0) `main._physics_process` runs *before* `selftest_driver._physics_process` within the same frame. A press-then-release in one driver call is therefore invisible to `main` — it never observes a frame where the action reads "just pressed". Hito 0's existing schedule always held actions across two consecutive ticks (e.g. `inspect_1` pressed at tick 80, released at tick 81); the new approach code broke that pattern.
- Options considered: press-and-release in the same call (broken, as found); explicit two-tick hold, matching the established pattern.
- Decision: any test-driven discrete action must be pressed on tick N and released on tick N+1 (or later), never both within the same driver call. `selftest_driver.gd` now tracks `_interact_press_pt` to enforce this for the dynamically-timed cabin-entry press.
- Why: this is a correctness property of the whole test harness, not a one-off fix — worth recording so a future added check doesn't repeat it.
- Consequences: none beyond the fix itself.
- Risks: none identified.
- Reversal trigger: none expected.
- Files/tests affected: `src/simulator/tests/selftest_driver.gd`.

## DEC-013 — Hito 1 ships gameplay/systems only; textures and a second machine are explicitly out of scope
- Date: 2026-07-27
- Status: accepted
- Context: the user's request covered a large surface (first-person player, cabin access, five cameras, real collision, readable telemetry, objectives, tutorial, texturing, and additional crane types) but also explicitly asked for "un hito por sesión, verificado y guardado" and to avoid another runaway-cost session.
- Evidence: user's own prioritisation in this conversation: experience-first over variety-first, one milestone per session.
- Options considered: attempt everything in one pass; scope this session strictly to the player/cabin/camera/collision/HUD/objective/tutorial systems on the existing overhead crane, deferring textures (H2) and additional machines (H3+).
- Decision: scoped to Hito 1 as listed. Textures/HDRI sky (Poly Haven CC0, pre-approved by the user) and a second machine are the next two milestones, each its own session.
- Why: matches the user's own stated cost-control preference; a large, uncommitted change is also the riskiest thing to leave unverified.
- Consequences: KI-006 (visuals still placeholder) is an explicit, accepted scope boundary, not an oversight.
- Risks: none identified.
- Reversal trigger: user asks to combine milestones in a future session.
- Files/tests affected: none (process decision).

## DEC-014 — SUPERSEDES DEC-006: pendant control station on the floor, not a cabin — nothing to climb
- Date: 2026-07-27
- Status: accepted
- Context: after playing Hito 1, the user (who has real factory lifting-floor experience) corrected the fixed-cabin design: this class of overhead crane (bovenloopkraan) is normally operated with a pendant/remote control box from a fixed point on the factory floor, not from an elevated cabin. There is nothing to climb.
- Evidence: user's own operational description in this conversation; real bovenloopkraan installations commonly use a wall/post-mounted pendant station precisely because the operator needs to watch the load from the ground, at a safe distance, not from above it.
- Options considered: keep the cabin/ladder (wrong per the correction); replace it with a ground-level pendant station the player walks to and "picks up" instantly.
- Decision: `MachineAccess` drops `CLIMBING_UP`/`CLIMBING_DOWN`/`IN_CABIN` entirely — the only states are `OUTSIDE`, `IN_ZONE`, `CONTROLLING`, and picking the pendant up/putting it down is instantaneous (it's a handheld box, not a structure to climb). `AppSettings.ACCESS_POINT` moves to `Vector3(1.0, 0.0, 9.0)` — x=1.0 is strictly less than `CraneRig.bridge_limits.x` (2.0), so the bridge/trolley can PHYSICALLY never reach the station; this is a provable safe distance, not a tuned approximation. `CameraDirector` loses its CABIN mode; HOME is now always first-person (`_update_walk()` unconditionally), since operating and walking are the same physical situation for this machine.
- Why: matches how this equipment is actually operated, per the user's direct correction — the previous design was not a stylistic choice, it was factually wrong about the machine.
- Consequences: `core/world_builder.gd`'s ladder marker is replaced with a control-box/post visual; `slice_overhead/main.gd` drops the climb-interpolation code entirely (`_drive_player()` just freezes the player in place while controlling); the scene selftest's approach phase no longer waits through a climb, so `pendant_pickup_works`/`pendant_putdown_works` resolve within 1-2 ticks of the key press instead of a fixed 2.5s duration.
- Risks: none identified — this is strictly simpler than what it replaces.
- Reversal trigger: a future machine (mobile crane, tower crane) whose real operator position genuinely is an elevated, structure-mounted cab — build that fresh for that machine rather than reviving this cabin design.
- Files/tests affected: `core/machine_access.gd`, `core/camera_director.gd`, `core/world_builder.gd`, `core/settings.gd`, `core/loc.gd`, `core/tutorial_guide.gd`, `slice_overhead/main.gd`, `tests/module_tests.gd`, `tests/selftest_driver.gd`.

## DEC-015 — Load impacts get a real physical response (bounce/damping), applied externally to the trusted integrator
- Date: 2026-07-27
- Status: accepted
- Context: the user explicitly asked for real consequences on impact — "si golpeo algo, quiero que tenga físicas destruidas o de rebote, de inercia, de impacto" — not just detection-and-log (Hito 1's KI-004 scope boundary). They also confirmed the existing swing/inertia physics feel correct and should not be touched.
- Evidence: `tests/module_tests.gd::_test_load_body_impact_response` — a load penetrating the floor at (0, 0.2, 0) moving down at 3 m/s is corrected to sit exactly on the surface (y=0.45, box-centre convention) with velocity reflected at 0.3 restitution and 0.8 tangential damping; a column penetration is pushed out along the axis of least overlap with the same reflection.
- Options considered: hand the load to the engine as a dynamic RigidBody3D once near a surface (risks silently diverging from the validated free-swing integrator); keep `cable_load_sim.gd` as the sole source of truth and apply a correction to its public `load_pos`/`load_vel` from `main.gd` whenever a contact is detected, exactly once per tick, after the sim has already integrated.
- Decision: the external-correction approach. `LoadBody.resolve_floor_contact()` / `resolve_column_contact()` are pure static functions returning a corrected centre/velocity; `main.gd::_resolve_load_impacts()` applies them by writing directly to `sim.load_pos`/`sim.load_vel`. `cable_load_sim.gd` itself is not modified.
- Why: preserves every pendulum/determinism guarantee already validated (DEC-009's reasoning extends directly here) while still giving a genuine physical consequence — quick taps vs. sustained thrust still produce different momentum through the SAME cable dynamics as before; what's new is what happens when that momentum meets something solid.
- Consequences: fixed a real, separate bug while implementing this — the floor/column checks had been called with `sim.load_pos` (the cable-attachment point) directly, but `LOAD_SIZE`-based checks assume a box CENTRE, which is `load_pos - (0, 0.5, 0)` per the visual offset already used in `_sync_visuals()`. Contact was firing about 0.5 m too early. Now `main.gd::_load_box_center()` is the single place that offset is applied, and all contact/impact functions take that as input.
- Risks: restitution/damping constants (0.3 / 0.8) are a reasonable first pass, not tuned against any reference; revisit if bounce feels wrong once visually inspected.
- Reversal trigger: none expected short of moving to full engine-driven rigid-body physics for the load, which would need its own validation pass against the existing pendulum tests.
- Files/tests affected: `core/load_body.gd`, `slice_overhead/main.gd`, `tests/module_tests.gd`.

## DEC-016 — Near-miss safety radius, separate from the exact contact box
- Date: 2026-07-27
- Status: accepted
- Context: the user described the real MVP behaviour as "normalmente [el operador] la hace siempre a una distancia prudencial controlando el radio de acción para que no te dé golpe el péndulo ni golpees nada de al lado" — i.e. the skill being trained is staying clear of the load's swing radius, not just avoiding literal contact. This is also explicit in `.claude/rules/simulation-physics.md`: "separate physical collision volumes from safety/near-miss volumes."
- Evidence: `tests/module_tests.gd::_test_load_safety_radius`; `AppSettings.LOAD_SAFETY_RADIUS_M := 2.0`, larger than `LoadBody.LOAD_SIZE`'s ~0.85 m half-diagonal.
- Options considered: only flag actual contact (Hito 1's behaviour); add a second, larger radius that triggers a lighter caution rather than a hard violation.
- Decision: `LoadBody.is_within_safety_radius()` (pure static function) checks a 2.0 m radius around the load's box centre against the player's position. Entering it flashes an amber caution (distinct from the red "contact" danger flash) and increments `Objectives.near_misses` — tracked in the score, but does NOT fail the lift the way an actual collision/violation does.
- Why: teaches situational awareness (stay clear of the operating envelope) as a distinct, lesser lesson from "never touch the load" (DEC-008) — matching how real lifting-safety training separates "too close" from "struck."
- Consequences: a translucent red disc (`WorldBuilder.safety_ring`) follows the load's XZ position on the floor each frame, giving a visible, real-time boundary — not just a HUD number.
- Risks: none identified.
- Reversal trigger: none expected.
- Files/tests affected: `core/load_body.gd`, `core/objectives.gd`, `core/world_builder.gd`, `core/hud.gd`, `core/loc.gd`, `slice_overhead/main.gd`.

## DEC-017 — Big on-screen key caps that light up on press, instead of printed control text
- Date: 2026-07-27
- Status: accepted
- Context: the user asked explicitly for game-capture-style controls: "haz los controles más grandes... que se vea dónde estoy pulsando" — confirming small printed text (the existing `controls_label`) wasn't legible/satisfying at a glance.
- Evidence: `core/hud.gd::KeyCap` — a `Control` subclass drawing a filled rounded rect that swaps colour the instant its bound `Input.is_action_pressed()` reads true.
- Options considered: enlarge the existing text label; add a dedicated WASD-shaped key cluster with live highlight, the way game-streaming overlays do.
- Decision: the key cluster. W/A/S/D always shown in their physical layout; SHIFT, and one context-swapped slot (SPACE=jump on foot / Q=hoist-up while controlling), plus E (interact on foot / hoist-down while controlling) — each cap re-checks the CONTEXTUALLY correct action every frame (mirrors the existing dual-purpose key bindings, e.g. W = move_forward on foot, bridge_fwd while controlling).
- Why: directly answers the request; also visually reinforces which of the two meanings a shared physical key currently has, which is otherwise easy to forget.
- Consequences: the printed `controls_label` text is kept alongside it (for the less-common keys: V, R, Tab, C, F1, L) — the key cluster covers the keys used constantly, not the full reference.
- Risks: none identified. Visual placement/sizing has not been visually inspected this session (see KI-008) — the DATA driving each cap (label + pressed state) is unit-verifiable, the LAYOUT is not, without looking at it.
- Reversal trigger: none expected.
- Files/tests affected: `core/hud.gd`.

## DEC-018 — Multiple pickup/placement scenario variants (boxes, heights, tight spaces) are the next milestone, not this one
- Date: 2026-07-27
- Status: accepted
- Context: the user asked for several scenario variations in the same message as the pendant-control correction: approach-and-lift-from-boxes, a bigger load, a load wedged between boxes, higher and lower placements. Building new geometry (box stacks) and 4-5 new scenario definitions is a substantial, separable unit of work from the corrections above.
- Evidence: user's own established pattern this session — "un hito por sesión, verificado y guardado" — and the fact that the corrections in DEC-014..017 already touch nearly every gameplay file in the slice.
- Options considered: cram the new scenarios into this same session; scope them as the explicit next milestone.
- Decision: deferred to the next session, building on the now-corrected pendant/collision/bounce foundation (which makes each new scenario cheaper, since the hard parts — access, camera, contact physics, scoring — are already in place and reusable).
- Why: keeps this session's diff reviewable and verifiable; a foundation correction (pendant control, real bounce physics) is exactly the kind of change that should land and be confirmed working before piling new content on top of it.
- Consequences: `scenarios/` still holds only SC-001. `objectives.gd`'s data-driven design (pickup/dropoff zones, mass, swing budget all read from a JSON file) already supports adding SC-002+ without further code changes to that module — only new JSON files plus whatever new geometry (box stacks) a given scenario needs.
- Risks: none identified.
- Reversal trigger: user asks for it explicitly, accepting the larger session cost.
- Files/tests affected: none yet (documented scope boundary for the next session).

---

## Slice 002 — multi-machine release (2026-08-03)

### DEC-019 — A machine is data, not code
**Context.** The brief asked for many more cranes, sites and weather. The
slice-001 code had bridge/trolley/hoist hard-coded through the rig, the world
builder, the HUD and the input map.
**Decision.** Describe every machine with one shared six-axis vocabulary
(`travel`, `trolley`, `slew`, `luff`, `telescope`, `hoist`) in
`core/machine_catalog.gd`, and drive all of them from one solver,
`core/machine_rig.gd`. A machine omits the axes it does not have.
**Consequence.** Adding a crane is one catalogue entry plus one visual builder.
Nothing in the session, HUD, input layer or scoring knows which machine it is
driving. Going from one machine to seven required no change to `session.gd`.
**Rejected.** A class per crane type. It would have duplicated the limit,
acceleration and interlock logic seven times, and the seventh crane would have
diverged from the first within a release.

### DEC-020 — The same gesture means the same thing on every machine
**Context.** The single most damning feedback on slice 001 was that the player
could not work out how to pick up the pendant and drive the crane. The cause
was that bindings lived in four places — the input map, the HUD overlay, a
`.bat` file's echo lines and a loc string — and none was authoritative.
**Decision.** `core/control_scheme.gd` is the single specification. The input
map, the live key overlay, the F1 card, the pause screen, the menu reference and
the guidance text all read from it. W/S is always "reach out/in", A/D is always
"left/right or slew", **R/F is always hoist**, T/G is always boom, SHIFT is
always creep, SPACE is always ALL STOP.
**Consequence.** A learner who has driven the workshop crane already knows two
thirds of the mobile crane. A binding change updates everything that teaches it,
or nothing. The scene selftest presses every binding through the real input map
on every machine, so a dead control fails a test rather than a learner.
**Also changed.** Hoist moved off Q/E to R/F, and reset moved off R to
BACKSPACE — reaching for "raise" and resetting the lift was a real hazard in
the old layout.

### DEC-021 — Guidance is a pure function of state, not a scripted tutorial
**Context.** A linear tutorial breaks the moment the learner does something out
of order, and then says nothing at all.
**Decision.** `core/guidance.gd` returns the first incomplete step given the
current state. No timers, no sequence, no Loc dependency.
**Consequence.** It recovers correctly from any order, including undoing a
step — dropping the controls mid-job returns to "walk to the control position",
which is asserted as a regression test. Because it carries no autoload
dependency it is unit-testable; the session turns its step ids into sentences
with the current machine's own keys substituted in.

### DEC-022 — Load charts are training envelopes, never manufacturer data
**Context.** Reading a chart and respecting a load moment is the most-examined
skill for mobile and tower cranes, and the project's rules forbid inventing
certification-relevant facts.
**Decision.** Every chart carries `chart_source:
training_envelope_not_manufacturer_data`; the catalogue, the UI, the README and
the licence all repeat it; `catalog_integrity` fails the test suite if any
machine's chart is not labelled. Real charts are a paid, per-customer,
configuration-keyed deliverable and never enter this repository.
**Consequence.** The *skill* transfers without the build ever asserting a rated
capacity for a real crane.

### DEC-023 — Hazard zones carry a height band
**Context.** The first implementation made any lifted load over a marked
rectangle a violation. That made the street site unplayable: the overhead-line
zone spanned the whole working area, so working *underneath* the wire — which is
the entire point of the closed lane — scored as a violation.
**Decision.** `hazard_zone()` takes `y_min`/`y_max`. Traffic lanes and pavements
apply at any height above the ground; overhead lines apply only near the wire.
**Consequence.** The rule the site teaches is the rule that is actually scored.
Zones were also removed from the laydown areas and the port truck lane, because
a rule that forbids the job teaches nothing.

### DEC-024 — Stability is taken about a tipping EDGE, not a distance to the boundary
**Context.** The first stability model computed the distance from the slew centre
to the support-polygon boundary along the boom bearing. The unit test caught
that it made a corner *less* stable than the middle of a side, which is
backwards.
**Decision.** Take moments about the polygon edge the load is working over:
resisting arm is the half-extent to that edge, the load's arm is its radius
component perpendicular to it.
**Consequence.** A corner is now markedly more stable than a side at the same
radius, which is the real behaviour and the reason set-up orientation is taught.
A regression test asserts `max_stable_radius` and `stability_factor` agree.

### DEC-025 — Loc is a static table; data modules carry no autoload dependency
**Context.** `module_tests.gd` runs under `--script`, where autoload globals do
not exist. Every catalogue referenced `Loc` to render its `{en, es, nl}` names,
so none of them could be compiled or tested standalone, and a cascade of
"Identifier not found" errors masked real failures.
**Decision.** `Loc.lang`, `Loc.t()` and `Loc.pick()` are static. Data modules
reach them through `preload("res://core/loc.gd")`. `Loc` no longer writes to
`GameState`; it emits `language_changed` and `GameState` listens. `ScenarioDB`
takes a predicate instead of reading progress directly.
**Consequence.** Every pure module compiles and is testable without the autoload
graph, and the test output is clean rather than buried in cascading noise.

### DEC-026 — Verify visually, not just by log
**Context.** Slice 001 closed with KI-008: "UI verification is headless and
log-based, not visually inspected." That gap hid real defects.
**Decision.** `-- --screenshot=<dir> --view=<mode>` renders, captures the
viewport and quits. Screenshot review is now part of release verification.
**Consequence.** It immediately found three defects that produced no log error
at all: a black hall floor (roof shadowing the interior), the orbit camera
clipping through the cladding, and the load-chart panel covering the objective
panel. None would have been caught by 94 passing assertions. KI-008 is closed.

### DEC-027 — Publish the engine, withhold the assessment layer
**Context.** The brief asked to publish to GitHub while protecting whatever
makes the product sellable.
**Decision.** The complete simulator is public under PolyForm Noncommercial
1.0.0. The competency model, validated thresholds, licence mapping, cohort
reporting and real-chart sourcing live in `COMMERCIAL/`, which is protected by
three independent barriers: `.gitignore`, an allow-list export
(`scripts/build_public_export.mjs`), and a confidential-marker grep over the
exported tree. The public repository is created fresh with no shared history, so
nothing previously committed privately can be recovered from it.
**Consequence.** The engine is not the moat — domain access and validation work
are. Publishing buys the credibility a small operation most lacks, while the
part that is genuinely hard to reproduce stays private.
