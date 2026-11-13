# 01 — Architecture

**Purpose:** Establish the system model and boundaries before changing components.

**Confidence note:** Verified against repository instructions and available files on 2026-11-13. No implementation is present to verify data flows. The code wins (see 16).

## Model and ownership

The workspace names four separate repositories: `sentinel-web` (front-end with regulatory compliance), `sentinel-android` (Android application), `sentinel-api` (backend described as communicating between Supabase Database API and web/Android clients), and `sentinel-specs` (product ecosystem specifications). Those ownership descriptions come from component `AGENTS.md` files; no source confirms actual runtime topology.

## Data flow and hard boundaries

**Unverified:** The intended API description suggests clients communicate through the API with Supabase, but routes, schemas, authentication, and whether clients also access Supabase directly are not available. Do not design a change based on this inferred flow until source, deployment config, and schema are present. Keep platform-specific behavior in its owning repository and shared product contracts in specs unless code demonstrates a different boundary.

## Decisions and inherited tradeoffs

No implementation decision records or project history are available. The maturity-based promotion workflow in `../git-guidelines.md` is an explicit process rule, not proof that branches or deployment automation currently implement it.

## Debt register (ranked)

1. **Critical — implementation cannot be inspected.** All four repositories have no commits and contain only instruction files (plus the specs git guide). Miss → reviewers cannot establish compatibility, security, or deployability.
2. **High — architecture and contracts are undocumented.** No route, database, or client contract evidence exists. Miss → independent implementations may drift.
3. **High — no test or CI evidence.** No workflows or test files exist in the snapshot. Miss → there is no reproducible confidence gate.
