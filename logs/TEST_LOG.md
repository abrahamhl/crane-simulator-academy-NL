# Test Log

Append-only. Record: date, test ID, command, result, notes.

## 2026-07-17 — Slice 001 physics proof (Godot 4.6.3.stable.official.7d41c59c4)

### T-001 — Headless project import
- Command: `tools/godot/Godot_v4.6.3-stable_win64_console.exe --headless --path src/simulator --import`
- Result: PASS — no parse errors, no missing resources; autoloads and main scene resolve.

### T-002 — Physics module tests (deterministic, no scene)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --headless --path src/simulator --script res://tests/module_tests.gd -- --out=<ABS>/logs`
- Result: PASS 7/7, exit 0 → `logs/MODULE_TEST_RESULTS.json`, stdout in `logs/module_tests_stdout.txt`
  - `longer_cable_longer_period`: T(4 m)=4.0188 s, T(8 m)=5.6834 s
  - `period_matches_theory`: err vs 2π√(L/g) 0.15%; T8/T4 vs √2 err 0.00%
  - `seeded_run_deterministic`: identical MD5 `a5aa33c4e1fcc06030e0d0fae6c6734d`
  - `wind_changes_trajectory`: wind hash ≠ no-wind hash
  - `zero_wind_deterministic`: identical hashes across different seeds with wind off
  - `wind_causes_lateral_displacement`: 0.000000 m → 0.1149 m at 8 m/s (drag-equilibrium hand-calc ≈0.115 m)
  - `no_nan_or_infinity_under_stress`: 0 violations over 3600 steps (slack/shock + gusts + hoist sweep)

### T-003 — Scene end-to-end selftest (real main scene, real InputMap actions)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --headless --fixed-fps 60 --path src/simulator -- --selftest --out=<ABS>/logs`
- Run 1: FAIL 15/16, exit 1 — `hoist_retracts` measured before the accel-limited hoist drive (0.45 m/s², max 0.35 m/s) had settled after key release (~47 ticks of coast); cable read 5.599→5.650 m. Physics correct; test schedule wrong. Fix: settle windows + full 120-tick up-phase in `tests/selftest_driver.gd`.
- Run 2: PASS 16/16, exit 0 → `logs/SELFTEST_RESULTS.json`, stdout in `logs/selftest_stdout.txt`
  - unpowered_start; no_motion_before_inspection (bridge_x bit-identical after 70 ticks of blocked input); inspection_enables_power
  - bridge_responds 10.000→11.044 m; trolley_responds 9.000→9.902 m; hoist_extends 5.000→5.700 m; hoist_retracts 5.700→5.000 m
  - load_swings max 12.87°; telemetry_updates +240 rows in 240 ticks; cable_visible_matches (visual 5.010 m vs sim 5.010 m)
  - hud_populated_bilingual (NL+EN labels present); wind_applied peak 8.31 m/s; wind_changes_behaviour mean lateral offset −0.0542 m → +0.0511 m toward +Z
  - camera_reset (orbit then exact restore); reset_deterministic — trajectory hash `da72cb6efc291dc441ff15ca4680f571` identical across two in-run resets and identical to run 1's value (cross-process determinism); no_nan_or_infinity (0 observations, 2541 ticks)

### T-004 — Windowed launch
- Command: `...Godot_v4.6.3-stable_win64_console.exe --path src/simulator --quit-after 240`
- Result: PASS, exit 0 — Vulkan 1.4.341 Forward+ on RTX 3060 Laptop GPU, zero errors/warnings (`logs/windowed_run_stdout.txt`).

## 2026-07-27 — Hito 1 verification (Godot 4.6.3.stable.official.7d41c59c4)

### T-005 — Headless project import (post-refactor)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --headless --path src/simulator --import`
- Result: PASS, clean. Two parse errors found and fixed during development before this final clean run: (1) `_sync_visuals()`/`_update_cable_visual()` were dropped when `main.gd` was rewritten as an orchestrator — restored, reading from `world.*` instead of local fields; (2) `var t := access.climb_progress()` failed type inference because `access` is statically typed as the base `RefCounted` — fixed with an explicit `var t: float =`.

### T-006 — Pure-logic module tests (no scene)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --headless --path src/simulator --script res://tests/module_tests.gd -- --out=<ABS>/logs`
- Result: PASS 12/12, exit 0 → `logs/MODULE_TEST_RESULTS.json`, stdout in `logs/module_tests_stdout.txt`. The original 7 (pendulum period, determinism, wind, NaN stress) unchanged and still pass; 5 new:
  - `objectives_pickup_then_delivery`: not_started → carrying → delivered, `score.passed=true` (max swing 0.50°)
  - `objectives_fails_on_excess_swing`: delivered=true but `passed=false` when max swing (5.00°) exceeds the 2.0° budget
  - `tutorial_guide_covers_all_states`: 8/8 state → instruction mappings correct
  - `machine_access_full_cycle`: outside → in_zone → interact → climbing_up → in_cabin → exit → climbing_down → outside, all transitions correct. First run of this test FAILED (ended at "in_zone" instead of "outside") — not a code defect: the test kept feeding the ladder's exact coordinates after climbing down, and the state machine correctly re-detected "still standing at the ladder foot" as IN_ZONE. Fixed by stepping the simulated player away before the final assertion.
  - `load_body_collision_math`: unconditional danger flag, push vector nonzero, AABB overlap true/false cases, floor and column contact true/false cases — all correct.

### T-007 — Scene end-to-end selftest (real main scene, real InputMap actions, real CharacterBody3D collision)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --headless --fixed-fps 60 --path src/simulator -- --selftest --out=<ABS>/logs`
- Run 1: FAIL 20/21 (`cabin_entry_works` — "did not reach cabin within 1401 approach ticks"). Diagnosed with temporary debug prints: the player successfully walked to and was correctly detected inside the ladder's access zone (`access=in_zone`) at approach-tick 700, then never moved again for the rest of the run. Root cause: the new approach-phase code pressed AND released the `interact` input action within the same driver call; `main.gd`'s edge detector (which runs once per physics frame, before the driver's own frame — established since Hito 0) never observed a "just pressed" frame, so `access.try_interact()` was never invoked. Documented as DEC-012 (a property of the whole test harness: any test-driven discrete action must be held across two ticks, matching the pattern Hito 0 already used everywhere else, e.g. `inspect_1` pressed at tick 80 / released at tick 81). Fixed by splitting the press and release across two ticks (`_interact_press_pt`).
- Run 1 also surfaced two `[FAIL]` results caused by a second, unrelated bug: `camera_reset` ("orbited=false") and `camera_modes_distinct` ("all views identical at (2.0, 9.3, 2.2)"). Root cause: `core/camera_director.gd` reads its OWN `rig`/`sim` fields (declared for this exact purpose) but `main.gd` never assigned them — every camera mode except CABIN's position-only line silently failed with `Nonexistent function 'support_point' in base 'Nil'` (2484 occurrences in the log), so the camera transform never actually updated for ORBIT/HOOK/TOPDOWN. Fixed by assigning `cam.rig = rig; cam.sim = sim` every frame in `main._process()` (a one-time assignment in `_ready()` would go stale, since `_reset_all()` replaces `rig`/`sim` with new instances on every reset).
- Run 2 (after both fixes): **PASS 21/21, exit 0** → `logs/SELFTEST_RESULTS.json`, stdout in `logs/selftest_stdout.txt`.
  - `player_spawns_on_foot`; `player_blocked_by_column` (real `CharacterBody3D` walked into a real `StaticBody3D` column at x=10, drift 0.0000 m over 60 ticks while still pressing forward, position clear of the column face); `cabin_entry_works` (entered after 843 approach ticks / 14.1 s of dynamic steering + climb)
  - All 16 original Hito-0 checks unchanged and still passing (unpowered start, inspection gate, bridge/trolley/hoist response, swing, telemetry, cable visual, wind, reset determinism — trajectory hash `da72cb6e...` still bit-identical, no NaN/Infinity)
  - `hud_populated_bilingual` — assertion updated to check "Cable length" + "Longitud de cable" (EN/ES, the new default pair) instead of the old EN/NL pair — an intentional change matching DEC-005, not a weakened check
  - `camera_reset` (now via explicit Tab-into-ORBIT first, per DEC-011); `camera_modes_distinct` (hook/topdown/cabin/orbit-default all pairwise distinct transforms)
  - `cabin_exit_works` (in_cabin=false 160 ticks after pressing F — within the 2.5 s climb-down duration + buffer)

### T-008 — Windowed launch (post-refactor)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --path src/simulator --quit-after 300`
- Result: PASS, exit 0 — Vulkan 1.4.341 Forward+ on RTX 3060 Laptop GPU, zero errors/warnings.

### Not verified this session
Visual appearance of the HUD gauges, minimap and tutorial panel layout was NOT visually inspected (no screenshot tool used against the native Godot window this session) — see KI-008. All 33 automated checks (12 module + 21 scene) pass, which verifies behavioural correctness, not on-screen layout/readability.

## 2026-07-27 (same day, continued) — Correction verification: pendant control, real bounce, safety radius (Godot 4.6.3.stable.official.7d41c59c4)

### T-009 — Headless project import (post-correction)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --headless --path src/simulator --import`
- Result: PASS, clean, first try — no parse errors introduced by the machine_access/camera_director/load_body/main.gd rewrite.

### T-010 — Pure-logic module tests (no scene)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --headless --path src/simulator --script res://tests/module_tests.gd -- --out=<ABS>/logs`
- Run 1: FAIL to even load — `SCRIPT ERROR: Parse Error: Cannot infer the type of "floor_ok"/"col_ok" variable`. Same class of bug as Hito 1's type-inference issue: `var floor_ok := floor_hit.hit and ...` fails because `floor_hit` is a `Dictionary` and `.hit`/`.center`/`.vel` field access returns an untyped Variant, which `:=` can't infer through a boolean expression. Fixed with explicit `var floor_ok: bool = ...` / `var col_ok: bool = ...`.
- Run 2: **PASS 14/14**, exit 0 → `logs/MODULE_TEST_RESULTS.json`. The 12 from Hito 1 unchanged (with `machine_access_full_cycle` rewritten for the instant pickup/putdown model — no climb states left to test) plus 2 new:
  - `load_body_impact_response`: floor bounce — penetrating at y=0.2 moving down at 3 m/s corrects to y=0.45 (exactly touching) with vel=(0.8, 0.9, 0.4) — matches restitution 0.3 / damping 0.8 by hand calculation exactly; clear and "leaving" (moving away while still overlapping) cases correctly report no hit. Column bounce — pushed out along the axis of least penetration (X here) to x=10.8, vel=(0.6, 0.0, 0.8), clear case no hit.
  - `load_safety_radius_distinguishes_near_miss`: 1.0 m away (within the 2.0 m radius) reads as near; 3.0 m away does not.

### T-011 — Scene end-to-end selftest (real main scene, pendant control station, real bounce)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --headless --fixed-fps 60 --path src/simulator -- --selftest --out=<ABS>/logs`
- Result: **PASS 21/21, exit 0** on the first run after the rewrite (no new bugs surfaced at the integration level, since the module-level bugs were already caught and fixed in T-010) → `logs/SELFTEST_RESULTS.json`.
  - `player_spawns_on_foot`; `player_blocked_by_column` (unchanged from Hito 1 — same collision mechanic)
  - `pendant_pickup_works` (picked up after 739 approach ticks / 12.3 s — faster than Hito 1's cabin entry since there is no climb to wait through, just walk + instant pickup)
  - All 16 original Hito-0 checks unchanged and still passing (bit-identical trajectory hash `da72cb6e...` for `reset_deterministic` — proves the new bounce-resolution code never actually triggers during this scripted sequence, since the load never reaches the floor or a column in it; the validated free-swing trajectory is exactly as before)
  - `camera_reset`, `camera_modes_distinct` (hook/topdown/first-person/orbit-default all pairwise distinct — first-person view now sampled at the pendant station instead of a fixed cabin pose)
  - `pendant_putdown_works` (controlling=false only 5 ticks after pressing F — instant, vs. Hito 1's 160-tick climb-down wait)

### T-012 — Windowed launch (post-correction)
- Command: `...Godot_v4.6.3-stable_win64_console.exe --path src/simulator --quit-after 300`
- Result: PASS, exit 0 — Vulkan 1.4.341 Forward+ on RTX 3060 Laptop GPU, zero errors/warnings.

### Not verified this round
Same as T-008's note: on-screen appearance (HUD gauges, minimap, the new key-cap overlay, the new safety-radius floor ring, the bounce actually looking like a bounce) was not visually inspected — see KI-008 (updated) and KI-009 (bounce constants untuned). All 35 automated checks (14 module + 21 scene) verify behavioural/numerical correctness, not visual appearance.

---

## 2026-08-03 — Slice 002 multi-machine release

### Run 1 — module suite, after adding the new pure-logic modules
`godot --headless --path src/simulator --script res://tests/module_tests.gd`

**19/21 FAIL.** Three genuine problems, two of them in the code rather than the
tests:

- `rig_axis_limits_and_accel` — the TEST was wrong: 600 steps at 1/60 s is 10 s,
  and 48 m of travel at 0.8 m/s needs a full minute. Raised to 4000 steps.
- `stability_model` — the CODE was wrong. `tipping_distance` computed the
  distance to the support-polygon boundary along the boom bearing, which made a
  corner *less* stable than the middle of a side. Rewritten to take moments
  about the tipping edge (DEC-024).
- `guidance_state_machine` — `guidance.gd` referenced `Loc`, so the whole script
  failed to compile under `--script` where autoloads do not exist. Guidance is
  now Loc-free and the session assembles the sentences (DEC-021, DEC-025).

### Run 2 — module suite
**21/22 FAIL.** `stability_model` still failing on an assertion comparing
`Vector2` components to float64 literals with a 1e-9 tolerance. `Vector2` is
32-bit, so 3.6 round-trips as 3.59999990. Tolerance corrected to 1e-5 — a test
bug, not a code bug.

### Run 3 — module suite
**22/22 PASS.** Cascading "Identifier not found: Loc" noise from the autoload
graph also gone after DEC-025.

### Run 4 — scene selftest, first attempt
Hung with no output. Cause: three `var x := rig.method()` declarations in
`session.gd` could not infer a type from a `RefCounted` receiver, so the scene
failed to parse and the process sat in an empty main loop. Annotated explicitly.

### Run 5 — scene selftest
**34/34 PASS.** All 7 machines built in all 5 sites across every weather preset
used by content, all 21 scenarios constructed clean.

### Run 6 — scene selftest, deep checks widened to once per MACHINE
**94/94 PASS.** Previously the full interaction path ran once per run, which
proved nothing about the six machines it did not touch. Now every machine has
its control bindings pressed through the real input map, its outrigger interlock
exercised, its cameras cycled and its reset verified.

### Run 7 — render verification
- Headless import: clean.
- Windowed, Vulkan Forward+, RTX 3060 Laptop: clean for the menu and for
  SC-101, SC-105, SC-303, SC-404, SC-501 — no errors, no warnings.

### Run 8 — screenshot review (new this release, DEC-026)
Three defects that produced **no log output at all**:

1. Hall interior black. A shadow-casting directional sun behind the roof put the
   entire floor in shadow. Fixed: indoors the sun casts no shadow and the hall
   has always-on high-bay lamps.
2. Orbit camera outside the hall, looking at the inside face of the cladding;
   on the building site it sat inside the concrete frame. Fixed: framing derived
   from machine height, fenced to site bounds indoors, pitch raised indoors.
3. Load-chart panel drawn over the objective panel and off the right edge of the
   screen. Moved to the left column, fixed width, wrapped labels.

Re-captured and confirmed after each fix.

### Run 9 — full re-verification after all fixes
- `module_tests.gd` — **22/22 PASS**
- `selftest_driver.gd` — **94/94 PASS**
- Public export tree (`build/public`) runs the module suite standalone:
  **22/22 PASS**, leak check clean (14 path patterns, 2 confidential markers).
