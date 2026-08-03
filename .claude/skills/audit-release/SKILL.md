---
name: audit-release
description: Run an independent P0/P1/P2 audit and block incomplete releases.
context: fork
agent: independent-qa-auditor
---

Test actual behaviour, not plans. Verify launch, every advertised mode, inputs, cameras, complete workflow, physics, safety, localization, target performance and package contents. Fix only when authorised by the main agent; rerun failed tests and issue RELEASE, RELEASE_WITH_LIMITATIONS or BLOCK.
