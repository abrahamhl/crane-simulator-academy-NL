# Agent Charter

## Main agent
Owns architecture, integration, irreversible decisions and delivery. It does not perform every noisy subtask itself.

## Delegation policy
Use one focused subagent at a time unless tasks are genuinely independent. Parallel agents multiply usage and merge risk.

### vacancy-evidence-researcher
Current vacancies, English evidence, paid training, direct links and structured records.

### licence-safety-researcher
Dutch legal/industry rules, TCVT/VCA/rail/driver licences and authoritative safety evidence.

### simulation-physics-architect
Physics architecture, validation equations, machine abstraction and engine decisions.

### implementation-engineer
Godot project implementation, data contracts, tools, UI, controls, packaging and fixes.

### independent-qa-auditor
Attempts to break the release; validates claims, physics, usability, performance and packaging.

## Shared rules
- Write details to files and return concise summaries.
- Cite evidence and record access dates.
- Do not overwrite another agent’s authoritative output silently.
- Update project memory with durable facts only.
- Never log hidden chain-of-thought.
