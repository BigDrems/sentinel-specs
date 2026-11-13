# 14 — Developer workflows

**Purpose:** Provide repeatable contributor recipes that prevent known regressions.

**Confidence note:** Repository locations and commit/release guidelines verified on 2026-11-13. No setup, build, or test configuration is available. The code wins (see 16).

## Setup

There are no verified prerequisites or setup commands. The repositories are separate Git workspaces (`sentinel-api`, `sentinel-android`, `sentinel-web`, `sentinel-specs`). Inspect actual manifests before installing tools or dependencies.

## Recipes

### Make a coordinated contract change

1. Inspect the API, database schema, and both clients for mirrored fields and validators.
2. Add the exact locations to 04 and change every required copy in one reviewed change.
3. Run the repository's verified test commands and add contract coverage.
4. **Current limitation:** these source files and commands are absent, so this recipe is a checklist, not an executable procedure. See 04.
5. Add what surprised you to `INBOX.md`.

### Prepare a release candidate

1. Confirm planned development work is complete and QA has accepted the `beta` build.
2. Promote reviewed changes to `release`, publish that bundle, and run candidate testing there.
3. Create an immutable tag for the exact published candidate using `10_DEPLOYMENT.md` rules.
4. Obtain explicit production approval for the exact passing RC before deployment.
5. Add what surprised you to `INBOX.md`.

### Commit a change

Use the imperative, scoped format in `03_CODE_STYLE.md`; follow the project's exclusion of AI agents as commit authors. Add what surprised you to `INBOX.md`.
