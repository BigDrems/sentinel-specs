# 10 — Deployment

**Purpose:** Follow the documented promotion gates and preserve release traceability.

**Confidence note:** Process rules verified against `../git-guidelines.md` on 2026-11-13. Build pipelines, hosting targets, and deployment commands are not present. The code wins (see 16).

## Promotion order

The prescribed maturity flow is `main` → `beta` → `release` → production. `main` is development/unit testing; `beta` is QA/system testing; `release` is published-bundle independent integration testing. Production requires separate approval of the exact passing RC candidate. These are required process rules, not proof branches or gates exist today.

## Candidate and tag rules

- Tag candidates from the `release` branch only, on the exact commit/build published for testing. Never move or reuse a tag.
- Candidate suffix order: `a`, `b`, `rc`; failed candidates increment within that stage (`a2`, `b2`, `rc2`). Do not increment the patch build merely for candidate stage.
- For weekly release tags, use ISO weeks and the product prefixes: web `WCN`, API `BCN`, Android `ACN`, specs `SCN`. Start at `001` in the first commit's week; skip weeks with no commits; tag only finished weeks and chronologically; never tag the current week before Friday 5 PM local time. Use the last committer-dated commit of the week and annotated tags per `git-guidelines.md`.
- Specifications use review candidates and approved baselines in place of deployed software, as described by the guide.

The guide's tag tables are empty and all component repositories have no commits in this snapshot. Next base tags are therefore the documented initial values (`WCN.01.0.001`, `BCN.01.0.001`, `ACN.01.0.001`, `SCN.01.0.001`), subject to history verification before creating any tag. No deployment command or environment variable is known.
