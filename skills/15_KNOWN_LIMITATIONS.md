# 15 — Known limitations

**Purpose:** Surface gaps likely to surprise engineers using the available workspace.

**Confidence note:** Verified by inspecting all visible files and Git refs on 2026-11-13. The code wins (see 16).

## Ranked limitations

1. **Workspace lacks implementation.** `sentinel-api`, `sentinel-android`, and `sentinel-web` contain only their `AGENTS.md`; `sentinel-specs` contains its instructions and `git-guidelines.md`. Each repository has no commits or refs. This blocks verification of behavior and runnable builds.
2. **No operational evidence.** No CI, deployment config, tests, manifests, schema, observability, or runbooks are available. Runtime and security characteristics are unknown.
3. **Spec release tables are placeholders.** `git-guidelines.md` has empty tag tables and says initial tags are next. This workspace's component repos also have no history, so confirm source history before cutting tags.
4. **Instructions include template naming.** The Git guide uses `code-name` placeholders while repositories are named `sentinel-*`; interpret scopes using the actual product names as described in 03.

## Redesign candidates

Not assessable without implementation. First restore/recover the four repository histories and source snapshots; then replace these unknowns with verified architecture, contracts, and test evidence. No security weakness or product bug is confirmed by the available files.
