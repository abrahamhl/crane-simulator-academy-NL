# Architecture

The organising idea: **a machine is data, not code.** Adding a crane means
adding one entry to a catalogue and one visual builder. Nothing in the session,
the HUD, the input layer or the scoring knows which machine it is driving. That
is why going from one crane to seven did not require rewriting the simulator.

## Layers

```
                    data                          behaviour
  machine_catalog.gd  ── spec ──►  machine_rig.gd      kinematics, limits, interlocks
                                   machine_visual.gd   geometry, animated from the rig
                                   control_scheme.gd   bindings, HUD labels, help card
  environment_catalog ── id ────►  environments/*.gd   geometry, obstacles, hazard zones
  scenarios/*.json    ── job ───►  scenario_runner.gd  phases, violations, score
  weather.gd          ── preset ─► lighting, sky, fog, wind, precipitation
                                   game/session.gd     the only place they meet
```

## The six axes

Every machine in the catalogue is described with the same vocabulary, and simply
omits the axes it does not have:

| Axis | Meaning |
|---|---|
| `travel` | Linear along world X — bridge, gantry, rail bogie |
| `trolley` | Across the bridge (Z) for overhead/gantry; **along the jib** (radius) for a tower crane |
| `slew` | Rotation about Y |
| `luff` | Boom elevation above horizontal |
| `telescope` | Total boom length |
| `hoist` | Rope payout |

`MachineRig.support_point()` turns whichever axes exist into the world position
the rope hangs from. That is the only thing the cable simulation needs from the
machine, which is what keeps the physics independent of machine type.

`MachineRig.radius()` is defined once, here, and never recomputed elsewhere —
every load chart is indexed by it.

## Physics

`cable_load_sim.gd` is unchanged from the first release and deliberately so: a
point-mass load on an elastic, tension-only cable below a kinematically driven
support, with quadratic drag, integrated with semi-implicit Euler at 120 Hz
inside the 60 Hz tick. It is validated against `T = 2π√(L/g)` to within 0.2 %,
is deterministic for a seed, and fails visibly on NaN rather than continuing.

Contact is resolved **outside** that integrator: `session.gd` corrects
`load_pos`/`load_vel` after each tick from `load_body.gd`'s pure static
functions. The validated free-swing integrator is never modified.

## Tick order (not interchangeable)

1. Access + discrete actions — a control taken this frame acts this frame
2. `rig.step` — kinematics move the rope head
3. Wind, then the cable substeps — the load follows the head it can now see
4. Impact resolution — external correction on the trusted integrator
5. Hazards, LMI, stability — read the resolved state, never predict it
6. Scenario runner — scores what actually happened

## Testing

Two tiers, split by what each can reach.

**`tests/module_tests.gd`** runs under `--script`, where autoloads do not
exist. It therefore covers only pure logic — and every module it covers was
written to have no autoload dependency for exactly that reason. 22 checks:
pendulum period against theory, seeded determinism, NaN stress, catalogue
integrity, per-class kinematics against hand-computed values, the outrigger
interlock, load-chart interpolation and planning, sling arithmetic, tipping
geometry, and the guidance state machine.

**`tests/selftest_driver.gd`** runs inside a live session and rebuilds the
session for **every scenario in the database**, then runs the full interaction
path once **per machine**. 94 checks: all seven machines construct in all five
sites under every weather preset the content uses, every job's zones are
reachable by its own machine, every control pair actually moves its axis through
the real input map, ALL STOP brakes everything, every camera produces a finite
transform, and reset returns the machine home without moving the operator.

Both write JSON to `logs/`. `RUN_TESTS.bat` runs both.

## Visuals

No binary assets. Every surface is a procedural PBR material built at runtime
from `FastNoiseLite` into real albedo, roughness and normal maps
(`core/materials.gd`), applied with world-space triplanar mapping so one
material serves a 64 m floor and a 0.4 m column without stretching. It keeps
the repository small, offline and licence-clean, and it still gives grain, wear
and relief rather than flat programmer colours.

Screenshots for verification: `-- --scenario=SC-101 --screenshot=<dir>
--view=orbit`. Visual output being inspectable is how the hall's black floor and
the orbit camera clipping through the wall were found — neither produced a log
error.
