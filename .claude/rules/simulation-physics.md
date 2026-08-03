---
paths:
  - "src/**"
  - "tests/physics/**"
  - "scenarios/**"
---

- Fixed timestep and deterministic seeds.
- Validate pendulum period, damping, wind force, load moment and stability.
- Use training envelopes unless authoritative manufacturer data is supplied.
- Separate physical collision volumes from safety/near-miss volumes.
- Fail visibly on NaN/Infinity; never silently continue corrupted state.
