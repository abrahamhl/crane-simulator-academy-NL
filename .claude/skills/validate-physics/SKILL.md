---
name: validate-physics
description: Validate pendulum, wind, load moment, stability and deterministic physics.
context: fork
agent: simulation-physics-architect
---

Define numerical tolerances before testing. Validate:
- period versus cable length;
- damping and energy behaviour;
- support acceleration;
- wind direction and exposed area;
- tension and shock loading;
- load moment and tipping margin;
- fixed-step consistency.

Write machine-readable and human-readable reports under `tests/physics/`.
