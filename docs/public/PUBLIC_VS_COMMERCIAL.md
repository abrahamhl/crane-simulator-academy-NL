# What is in this repository, and what is deliberately not

This repository contains the **complete simulator**: physics, kinematics, all
seven machines, all five sites, all weather, all 21 scenarios, the full UI, and
both test suites. Nothing here is a crippled demo — the thing you can build and
run is the thing.

What is not here is the layer that would turn a training aid into an
**assessment product**. That separation is deliberate, and it is drawn along a
line that is worth stating plainly.

## Not included

**A competency model.** This build scores a lift with a flat, published points
table (`AppSettings.PENALTY`) and shows you every deduction. That is honest and
legible, and it is not an assessment. Mapping performance onto named licence
competencies, weighting them, and setting thresholds that survive contact with
an assessor is separate work.

**Validated pass thresholds.** `PASS_POINTS = 600` is a number chosen so the
game feels right. It has not been calibrated against anyone whose real
competence is independently known, and this repository does not claim otherwise.

**Real machine load charts.** Every capacity table in `machine_catalog.gd`
carries `chart_source: training_envelope_not_manufacturer_data`, and the UI
repeats it. They are plausible, internally consistent envelopes shaped like real
ones so that the *skill* of reading a chart transfers. They are not any real
crane's rated capacity and must never be used as one.

**Licence and vacancy research.** No claim about any employer, vacancy, salary,
language requirement, funded course or certification route appears anywhere in
this build, because none of it has been verified to the standard this project
requires (current, cited, with an access date).

**Cohort management, instructor reporting, multi-seat licensing.**

## Why publish the rest

Because the engine is not the moat. Anyone can clone this and get a good crane
trainer; that is fine, and it is useful. What is hard to reproduce is domain
access and validation work, and that is what stays private. Publishing the
engine costs little and buys the one thing a small operation selling to
conservative training providers most lacks: something real you can look at.

## Licence

The public build is released under **PolyForm Noncommercial 1.0.0**. Read it,
learn from it, use it personally, teach yourself with it. Do not sell it or use
it to run a commercial training operation. See `LICENSE`.
