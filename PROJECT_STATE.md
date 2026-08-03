# Project State

- **Phase:** Slice 002 — "Multi-machine release" VERIFIED (2026-08-03)
- **Engine:** Godot 4.6.3 stable (portable, `tools/godot/`), Jolt configured.
  Suspended-load physics remains engine-independent fixed-step math, unchanged
  since Hito 0 and still validated to 0.15 % against `2π√(L/g)`.

## What exists now

The single overhead-crane slice has been generalised into a complete simulator:

- **7 machines** — overhead 5 t and 16 t, lorry loader 8 tm, tower crane 45 m,
  mobile telescopic 40 t, rail-mounted slewing 25 t, ship-to-shore container
  gantry. All described by the same six-axis vocabulary in
  `core/machine_catalog.gd`; one generic solver (`core/machine_rig.gd`) drives
  all of them.
- **5 environments** — production hall, city street works, housing construction
  site, container terminal quay, rail maintenance yard. Each registers its own
  load obstacles, control position and scored hazard zones.
- **8 weather presets** — clear, overcast, rain, fog, dusk, night, snow, storm.
  Each changes wind, gusting, visibility, ground grip and lighting together.
- **21 scenarios** across 5 ordered training programmes, all validated at load
  time and re-validated in the scene selftest against the live rig.
- **Licence content** — load charts with LMI banding, load moment, stability and
  tipping geometry, sling angle and leg tension, pre-use checks, outrigger
  interlocks, signaller, and one scenario whose correct answer is to refuse the
  lift.
- **Game shell** — boot disclaimer, main menu with a 3D machine preview,
  training programme, scenario browser, free practice, controls reference,
  settings, progress, pause and an itemised results debrief. Persistent profile
  in `user://profile.json`.
- **Guidance layer** — a pure state machine (`core/guidance.gd`) that always
  states the next step and the keys for it, on any machine, in any order the
  learner does things.
- **Procedural PBR materials** — no binary art assets; every surface generated
  at runtime into albedo, roughness and normal maps.

## Verification (2026-08-03)

| Suite | Result |
|---|---|
| `tests/module_tests.gd` (pure logic, no autoloads) | **22/22 PASS** |
| `tests/selftest_driver.gd` (live sessions, all scenarios, all machines) | **94/94 PASS** |
| Headless import | clean |
| Windowed run, Vulkan Forward+ (RTX 3060) | clean, no errors or warnings |
| Screenshot review, every environment | done — found and fixed two defects no log reported |

## Defects found by screenshot review and fixed this session

- Hall floor rendered black: a shadow-casting directional sun behind the roof
  put the whole interior in shadow. Indoors the sun no longer casts shadows and
  the hall has always-on high-bay lamps.
- Orbit camera flew through the hall cladding and, on the building site, sat
  inside the concrete frame. Framing is now derived from machine height and
  fenced to the site bounds indoors.
- Load-chart panel covered the objective panel and ran off the right edge.
  Moved to the left column with a fixed width and wrapped labels.

## Known scope boundaries (not defects)

- **KI-010** Pick-ups and set-downs are ground-level only. Landing a load on an
  elevated slab needs a vertical obstacle resolver this release does not have,
  so no scenario asks for one.
- **KI-009** Bounce restitution/damping constants remain plausible first-pass
  values, not measurements.
- **KI-011** Stability is a static training model: no dynamic load swing, no
  braking transient, no ground bearing failure.
- **KI-012** Load charts are training envelopes, not manufacturer data, and are
  labelled as such in code, in the UI and in the README.
- **KI-013** Scoring is a flat published points table, not a validated
  assessment. The competency model is commercial and deliberately absent.

## Verified vacancies

0 — the research phase has not been resumed. Nothing in the build asserts any
employer, vacancy, salary, language requirement or funding route.

## P0 defects

0 known.

## Publication

`scripts/build_public_export.mjs` produces an allow-listed public tree with a
three-barrier leak check (`.gitignore`, allow-list, confidential-marker grep).
The working repository keeps full history privately; the public repository is
created fresh from the export with no shared history. See
`docs/public/PUBLIC_VS_COMMERCIAL.md` and `COMMERCIAL/README.md`.

## Next executable step

Resume the licence and vacancy research phases so `COMMERCIAL/COMPETENCY_MAPPING.md`
can be filled with cited, verified sources — it is currently an empty matrix by
design rather than plausible-looking invented rows.
