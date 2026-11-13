# 02 — Project structure

**Purpose:** Show where project code belongs and how repository naming maps to ownership.

**Confidence note:** Verified against visible repository layout on 2026-11-13. There are no source trees to annotate. The code wins (see 16).

## Workspace tree

```text
sentinel-ecosystem/
├── sentinel-api/       # Backend API; exact source layout unavailable
├── sentinel-android/   # Android app; exact source layout unavailable
├── sentinel-web/       # Web front end; exact source layout unavailable
└── sentinel-specs/
    ├── git-guidelines.md
    └── skills/         # Engineering handoff documents
```

Each component directory is a separate Git repository. In this snapshot, each has an `AGENTS.md`; `sentinel-specs` also has `git-guidelines.md`. No package manifests, build files, routing, migrations, or source directories were found.

## Where changes go

- Put web, Android, and API implementation changes in their respective repositories.
- Put product contracts and engineering documentation in `sentinel-specs`.
- This is an ownership mapping from repository names and instructions, not a verified module layout. Inspect the actual project tree before adding files.

No naming convention beyond repository and release-tag naming is evidenced. Avoid creating a presumed framework structure until the relevant maintainers or source establishes it.
