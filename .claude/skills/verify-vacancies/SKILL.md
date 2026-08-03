---
name: verify-vacancies
description: Verify current paid-entry crane, heavy-equipment and rail vacancies near Arnhem.
context: fork
agent: vacancy-evidence-researcher
---

Research the scope in `$ARGUMENTS` or the current project target.

Output:
- `research/VACANCY_DATABASE.csv`
- `research/VACANCY_EVIDENCE.md`
- `research/SOURCE_REGISTER.md`
- `research/RECRUITER_QUESTIONS_EN_ES.md`

Required states: active status, language evidence, paid-start evidence, training support, licence prerequisites, salary, hours, location, entry route and confidence. Do not promote a vacancy to APPLY NOW without explicit evidence.
