# 11 — Testing

**Purpose:** Explain what evidence currently supports confidence and what remains to establish.

**Confidence note:** No test files, CI workflows, build manifests, or executable source were found on 2026-11-13. The code wins (see 16).

## Coverage and confidence

Coverage is **unknown**, not zero measured coverage: there is no implementation snapshot to run or inspect. No unit, system, integration, regression, or security test commands can be stated honestly.

## Required evidence to add

When source is restored, document exact setup and test commands, CI workflows, external services and mocks, coverage scope, and known gaps. Prioritize API/database/client contract tests for lockstep sets (see 04), then capture manual drills for flows that cannot be automated. The release guide assigns unit testing to developers on `main`, system testing to QA on `beta`, and integration testing to independent testers against published `release` bundles.
