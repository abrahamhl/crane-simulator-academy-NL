# Changelog

## 1.0.0 — 2026-08-03 — Multi-machine release

The single overhead-crane slice becomes a complete simulator: seven machines,
five sites, eight weather conditions, twenty-one scenarios, and a game shell
around all of it.

### Added — machines
- Generic six-axis machine model (`travel`, `trolley`, `slew`, `luff`,
  `telescope`, `hoist`) in `core/machine_catalog.gd`, solved by one rig
  (`core/machine_rig.gd`). See DEC-019.
- Seven machines: overhead 5 t and 16 t, lorry loader 8 tm, tower crane 45 m,
  mobile telescopic 40 t, rail-mounted slewing 25 t, ship-to-shore gantry.
- `machines/machine_visual.gd` — lattice booms, telescoping sections, portal
  legs, outriggers that visibly deploy, spreader, cabs.

### Added — sites and conditions
- Five environments: production hall, city street works, housing construction
  site, container terminal quay, rail maintenance yard.
- Eight weather presets driving wind, gusting, visibility, ground grip,
  lighting, sky, fog and precipitation together.
- Height-banded hazard zones (DEC-023): traffic lanes and pavements at any
  height, overhead lines only near the wire.

### Added — licence content
- `core/load_chart.gd` — rated capacity by radius, LMI banding, load moment,
  max radius for a given load, honest "off the chart" instead of extrapolation.
- `core/stability_model.gd` — tipping about the support-polygon edge (DEC-024),
  outrigger footprint, stability factor bands.
- `core/rigging.gd` — gross load, sling angle factor, tension per leg, required
  WLL, conservative four-leg convention.
- Outrigger interlock: no slew, luff, telescope or travel until deployed.
- Signaller (`B`) for blind lifts.
- SC-404, whose correct answer is to refuse the lift.

### Added — shell and guidance
- Boot disclaimer, main menu with a live 3D machine preview, training
  programme, scenario browser, free practice, controls reference, settings,
  progress, pause menu, itemised results debrief.
- `core/guidance.gd` — a pure state machine that always states the next step
  and the keys for it, on any machine, in any order (DEC-021).
- Persistent learner profile with best-result-kept scoring.
- Three difficulty modes that change how much help is shown, never the physics.

### Added — visuals
- `core/materials.gd` — 30 procedural PBR materials generated at runtime into
  albedo, roughness and normal maps with world-space triplanar mapping. No
  binary art assets.
- Filmic tone mapping, SSAO, glow, procedural sky, volumetric-feel fog, GPU
  rain and snow.

### Added — verification
- `-- --screenshot=<dir> --view=<mode>` viewport capture (DEC-026), closing
  KI-008.
- `-- --scenario=<id>` to jump straight into one job.
- Module suite grew 14 → **22** checks; scene selftest grew 21 → **94** and now
  rebuilds the session for every scenario and runs the full interaction path
  once per machine.

### Changed
- **Controls are now identical across every machine** (DEC-020). Hoist moved to
  **R/F** on all machines; reset moved from R to BACKSPACE; ALL STOP on SPACE;
  outriggers on O; load chart on H. `control_scheme.gd` is the single
  specification that input, HUD, help card and guidance all read from.
- `Loc` is now a static table and emits `language_changed` instead of writing
  to `GameState`; data modules carry no autoload dependency (DEC-025).
- Ground contact only counts as a collision above an impact-speed threshold, so
  setting a load down gently is no longer scored as a crash.
- Licence changed from Apache-2.0 to **PolyForm Noncommercial 1.0.0** (DEC-027).

### Fixed (found by screenshot review, invisible in logs)
- Hall interior rendered black: a shadow-casting sun behind the roof. Indoors
  the sun no longer casts shadows and the hall has always-on high-bay lamps.
- Orbit camera flew through the hall cladding and sat inside the concrete frame
  on the building site. Framing now derives from machine height and is fenced to
  the site bounds indoors.
- Load-chart panel covered the objective panel and overflowed the screen edge.

### Fixed (found by tests)
- Stability model made a corner less stable than a side — backwards (DEC-024).
- Rail crane's slew centre did not move with its travel axis, making "drive
  closer to reduce the radius" impossible — which SC-504 depends on.

### Security / IP
- `COMMERCIAL/` added and protected by three independent barriers: `.gitignore`,
  the allow-list export `scripts/build_public_export.mjs`, and a
  confidential-marker grep over the exported tree.
- `docs/public/PUBLIC_VS_COMMERCIAL.md` states what is withheld and why.

### Removed
- `slice_overhead/`, `core/world_builder.gd`, `core/tutorial_guide.gd` and the
  original `core/hud.gd`, all superseded.


## 0.5.0 — 2026-07-28 — Portfolio release preparation

### Added
- Public-facing README centred on verified simulation and human-in-the-loop
  AI direction rather than unverified career claims.
- Apache-2.0 licence.
- `docs/AI_ORCHESTRATION_CASE_STUDY.md`, mapping the cabin-to-pendant
  correction to decisions, implementation and tests.

### Changed
- Windows launchers now describe the current first-person and pendant controls.
- Test launcher labels now match the verified 14 + 21 check suites.
- The old local update archive is explicitly ignored.

### Removed
- The unused root `scenarios/` placeholder. Active scenario data lives under
  `src/simulator/scenarios/`.

### Publication safety
- The working repository remains the private local source of truth.
- Public release must use a curated export so research seed material, local
  paths and private commit metadata are not published accidentally.

## 0.4.1 — 2026-07-27 — Correction: pendant control, real bounce, safety radius
Same-day follow-up after the user played 0.4.0 and corrected a factual error: this
overhead crane is pendant-operated from the factory floor, not from a cabin. Also
adds physical consequences that were previously detection-only.

### Changed
- **No more cabin or ladder.** The crane is now operated from a ground-level pendant
  control station — walk up to it, press E to pick it up (instant), operate, F to put
  it down. The station sits at a point the crane can physically never reach, so it is
  a genuinely safe place to stand, not just usually clear.
- The "cabin" camera view is gone; the first-person view is now used both for walking
  and for operating, since you never leave the factory floor.

### Added
- **Real impact physics.** The load now bounces off the floor and columns instead of
  just being logged as a collision — inertia carries through the impact, with some
  energy lost each bounce, tuned to feel plausible rather than perfectly elastic.
- **Safety radius.** A translucent red circle on the floor follows the load and marks
  a caution zone larger than the load itself — stepping into it (without actually
  touching the load) triggers an amber warning and a separate "near miss" count,
  distinct from an actual hit.
- **Big on-screen key display.** WASD shown in their physical layout, lighting up the
  instant each key is pressed, plus Shift and the two remaining action keys — answers
  the request to see controls "tipo videojuego."

### Fixed
- A real bug found while adding the bounce physics: floor/column contact had been
  checked against the wrong reference point on the load (off by 0.5 m), meaning
  contact could fire slightly earlier than it visually should have. Now consistent.

## 0.4.0 — 2026-07-27 — Hito 1: "Entrar a la grúa"
First-person playable pass over the Hito-0 physics proof. The crane and its physics are unchanged; everything around them is new.

### Added
- First-person on-foot player with real collision (walk the hall, get blocked by columns/walls, can't walk through the crane structure).
- Climbable access to a fixed operator cabin: walk to the marked ladder, press E, a scripted 2.5 s climb, then full crane control.
- Five camera views: cabin (first-person, looks at the hook), on-foot first-person, orbit, hook-cam, top-down. `Tab` cycles, `C` resets the active one.
- Real load-vs-player collision: the load can push you if you stand under it, and it is always flagged as a safety violation, regardless of speed — that's the actual safety rule, not a game simplification.
- Load-vs-floor and load-vs-column contact detection (logged as collisions; no physical bounce/rest response yet).
- On-screen, always-visible tutorial instruction — no more silent "press 1-2-3" rule. Every gate (walk to the ladder, climb in, complete the inspection, do the lift) is explained on screen as it becomes relevant.
- First scenario, SC-001: move a 500 kg pallet from a marked yellow zone to a marked blue zone, keeping swing under 2° — with a live score (time, max swing, collisions, safety violations).
- Redesigned HUD: a needle-style swing gauge with green/amber/red zones, a tension bar, a wind compass, and a top-down minimap showing the crane, the pickup/drop-off zones and the player.
- **Spanish added to the interface.** The HUD was English/Dutch only; it is now English/Spanish by default (Dutch still available via the language key). This was the direct fix for a reported unreadable HUD.
- Double-click launchers (`START_SIMULATOR.bat`, `RUN_TESTS.bat`) — carried over from the previous session, verified again this session.

### Verification
- 12/12 pure-logic unit tests pass (objectives scoring, tutorial instructions, cabin access state machine, collision math).
- 21/21 end-to-end scene tests pass — the original 16 Hito-0 checks (pendulum physics, wind, determinism, HUD, camera) all still pass unchanged, plus 5 new ones covering the player, collision, cabin entry/exit and the camera modes.
- Clean headless import, clean windowed launch.

### Known limitations (see `logs/KNOWN_ISSUES.md`)
- Visuals are still flat-coloured placeholder geometry — no textures yet (planned for the next milestone).
- The operator cabin is fixed in place, not mounted on the moving bridge.
- Load-vs-structure contact is detected and scored but has no physical response (the load doesn't bounce or come to rest against what it hits).
- The visual appearance of the new HUD/gauges has not been visually inspected this session — only verified to run without error. Look at it before trusting the layout.

## 0.2.0
- Desktop-first V2 starter; legacy browser skills deactivated.
